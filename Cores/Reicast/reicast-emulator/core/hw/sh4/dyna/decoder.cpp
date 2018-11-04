/*
	Ugly, hacky, bad code
	It decodes sh4 opcodes too
*/

#include "types.h"

#if FEAT_SHREC != DYNAREC_NONE

#include "decoder.h"
#include "shil.h"
#include "ngen.h"
#include "hw/sh4/sh4_opcode_list.h"
#include "hw/sh4/sh4_core.h"
#include "hw/sh4/sh4_mem.h"
#include "decoder_opcodes.h"

#define BLOCK_MAX_SH_OPS_SOFT 500
#define BLOCK_MAX_SH_OPS_HARD 511

RuntimeBlockInfo* blk;


const char idle_hash[] = 
	//BIOS
	">:1:05:BD3BE51F:1E886EE6:6BDB3F70:7FB25EA3:DE0083A8"
	">:1:04:CB0C9B99:5082FB07:50A46C46:4035B1F1:6A9F47DC"
	">:1:04:26AEABE5:E9D01A08:C25DD887:EEAFF173:CE2BBA10"
	">:1:0A:5785DC3D:68688650:C5E1AFB3:7F686AE5:89538042"

	//SC
	">:1:0A:5693F8B9:E5C0D65C:ABF59CAC:B05DF34C:4A359E4A"
	">:1:04:BC1C1C9C:C17809D5:1EA4548E:8CD97AFE:E263253F"
	">:1:04:DD9FDF9D:55306FAD:4B3FDAEF:1D58EE41:11301FF1"

	//HH
	">:1:07:3778EBBC:29B99980:3E6CBA8E:4CA0C16A:AD952F27"
	">:1:04:23F5F301:89CDFEC8:EBB8EB1A:57709C84:55EA4585"

	//these look very suspicious, but I'm not sure about any of them
	//cross testing w/ IKA makes them more suspects than not
	">:1:0D:DF0C1754:1E3DDC72:E845B7BF:AE1FC6D2:8644F261"
	">:1:04:DB35BCA0:AB19570C:0E0E54D7:CCA83E6E:A8D17744"

	//IKA

	//Also on HH, dunno if IDLESKIP
	//Looks like this one is
	">:1:04:DB35BCA0:AB19570C:0E0E54D7:CCA83E6E:A8D17744"

	//Similar to the hh 1:07 one, dunno if idleskip
	//Looks like yhis one is
	">:1:0D:DF0C1754:1E3DDC72:E845B7BF:AE1FC6D2:8644F261"

	//also does the -1 load
	//looks like this one is
	">1:08:AF4AC687:08BA1CD0:18592E67:45174350:C9EADF11";

shil_param mk_imm(u32 immv)
{
	return shil_param(FMT_IMM,immv);
}
shil_param mk_reg(Sh4RegType reg)
{
	return shil_param(reg);
}
shil_param mk_regi(int reg)
{
	return mk_reg((Sh4RegType)reg);
}
enum NextDecoderOperation
{
	NDO_NextOp,     //pc+=2
	NDO_End,        //End the block, Type = BlockEndType
	NDO_Delayslot,  //pc+=2, NextOp=DelayOp
	NDO_Jump,       //pc=JumpAddr,NextOp=JumpOp
};


struct
{
	NextDecoderOperation NextOp;
	NextDecoderOperation DelayOp;
	NextDecoderOperation JumpOp;
	u32 JumpAddr;
	u32 NextAddr;
	BlockEndType BlockType;

	struct
	{
		bool FPR64; //64 bit FPU opcodes
		bool FSZ64; //64 bit FPU moves
		bool RoundToZero; //false -> Round to nearest.
		u32 rpc;
		bool is_delayslot;
	} cpu;

	ngen_features ngen;

	struct
	{
		bool has_readm;
		bool has_writem;
		bool has_fpu;
	} info;

	void Setup(u32 rpc,fpscr_t fpu_cfg)
	{
		cpu.rpc=rpc;
		cpu.is_delayslot=false;
		cpu.FPR64=fpu_cfg.PR;
		cpu.FSZ64=fpu_cfg.SZ;
		cpu.RoundToZero=fpu_cfg.RM==1;
		verify(fpu_cfg.RM<2);
		//what about fp/fs ?

		NextOp=NDO_NextOp;
		BlockType=BET_SCL_Intr;
		JumpAddr=0xFFFFFFFF;
		NextAddr=0xFFFFFFFF;

		info.has_readm=false;
		info.has_writem=false;
		info.has_fpu=false;
	}
} state;

void Emit(shilop op,shil_param rd=shil_param(),shil_param rs1=shil_param(),shil_param rs2=shil_param(),u32 flags=0,shil_param rs3=shil_param(),shil_param rd2=shil_param())
{
	shil_opcode sp;
		
	sp.flags=flags;
	sp.op=op;
	sp.rd=(rd);
	sp.rd2=(rd2);
	sp.rs1=(rs1);
	sp.rs2=(rs2);
	sp.rs3=(rs3);
	sp.guest_offs=state.cpu.rpc-blk->addr;

	blk->oplist.push_back(sp);
}

void dec_fallback(u32 op)
{
	shil_opcode opcd;
	opcd.op=shop_ifb;

	opcd.rs1=shil_param(FMT_IMM,OpDesc[op]->NeedPC());

	opcd.rs2=shil_param(FMT_IMM,state.cpu.rpc+2);
	opcd.rs3=shil_param(FMT_IMM,op);
	blk->oplist.push_back(opcd);
}

#if 1

#define FMT_I32 ERROR!WRONG++!!
#define FMT_F32 ERROR!WRONG++!!
#define FMT_F32 ERROR!WRONG++!!
#define FMT_TYPE ERROR!WRONG++!!

#define FMT_REG ERROR!WRONG++!!
#define FMT_IMM ERROR!WRONG++!!

#define FMT_PARAM ERROR!WRONG++!!
#define FMT_MASK ERROR!WRONG++!!

void dec_DynamicSet(u32 regbase,u32 offs=0)
{
	if (offs==0)
		Emit(shop_jdyn,reg_pc_dyn,mk_reg((Sh4RegType)regbase));
	else
		Emit(shop_jdyn,reg_pc_dyn,mk_reg((Sh4RegType)regbase),mk_imm(offs));
}

void dec_End(u32 dst,BlockEndType flags,bool delay)
{
	if (state.ngen.OnlyDynamicEnds && flags == BET_StaticJump)
	{
		Emit(shop_mov32,mk_reg(reg_nextpc),mk_imm(dst));
		dec_DynamicSet(reg_nextpc);
		dec_End(0xFFFFFFFF,BET_DynamicJump,delay);
		return;
	}

	if (state.ngen.OnlyDynamicEnds)
	{
		verify(flags == BET_DynamicJump);
	}

	state.BlockType=flags;
	state.NextOp=delay?NDO_Delayslot:NDO_End;
	state.DelayOp=NDO_End;
	state.JumpAddr=dst;
	state.NextAddr=state.cpu.rpc+2+(delay?2:0);
}

#define GetN(str) ((str>>8) & 0xf)
#define GetM(str) ((str>>4) & 0xf)
#define GetImm4(str) ((str>>0) & 0xf)
#define GetImm8(str) ((str>>0) & 0xff)
#define GetSImm8(str) ((s8)((str>>0) & 0xff))
#define GetImm12(str) ((str>>0) & 0xfff)
#define GetSImm12(str) (((s16)((GetImm12(str))<<4))>>4)


#define SR_STATUS_MASK 0x700083F2
#define SR_T_MASK 1

u32 dec_jump_simm8(u32 op)
{
	return state.cpu.rpc + GetSImm8(op)*2 + 4;
}
u32 dec_jump_simm12(u32 op)
{
	return state.cpu.rpc + GetSImm12(op)*2 + 4;
}
u32 dec_set_pr()
{
	u32 retaddr=state.cpu.rpc + 4;
	Emit(shop_mov32,reg_pr,mk_imm(retaddr));
	return retaddr;
}
void dec_write_sr(shil_param src)
{
	Emit(shop_and,mk_reg(reg_sr_status),src,mk_imm(SR_STATUS_MASK));
	Emit(shop_and,mk_reg(reg_sr_T),src,mk_imm(SR_T_MASK));
}
//bf <bdisp8>
sh4dec(i1000_1011_iiii_iiii)
{
	dec_End(dec_jump_simm8(op),BET_Cond_0,false);
}
//bf.s <bdisp8>
sh4dec(i1000_1111_iiii_iiii)
{
	blk->has_jcond=true;
	Emit(shop_jcond,reg_pc_dyn,reg_sr_T);
	dec_End(dec_jump_simm8(op),BET_Cond_0,true);
}
//bt <bdisp8>
sh4dec(i1000_1001_iiii_iiii)
{
	dec_End(dec_jump_simm8(op),BET_Cond_1,false);
}
//bt.s <bdisp8>
sh4dec(i1000_1101_iiii_iiii)
{
	blk->has_jcond=true;
	Emit(shop_jcond,reg_pc_dyn,reg_sr_T);
	dec_End(dec_jump_simm8(op),BET_Cond_1,true);
}
//bra <bdisp12>
sh4dec(i1010_iiii_iiii_iiii)
{
	dec_End(dec_jump_simm12(op),BET_StaticJump,true);
}
//braf <REG_N>
sh4dec(i0000_nnnn_0010_0011)
{
	u32 n = GetN(op);

	dec_DynamicSet(reg_r0+n,state.cpu.rpc + 4);
	dec_End(0xFFFFFFFF,BET_DynamicJump,true);
}
//jmp @<REG_N>
sh4dec(i0100_nnnn_0010_1011)
{
	u32 n = GetN(op);

	dec_DynamicSet(reg_r0+n);
	dec_End(0xFFFFFFFF,BET_DynamicJump,true);
}
//bsr <bdisp12>
sh4dec(i1011_iiii_iiii_iiii)
{
	//TODO: set PR
	dec_set_pr();
	dec_End(dec_jump_simm12(op),BET_StaticCall,true);
}
//bsrf <REG_N>
sh4dec(i0000_nnnn_0000_0011)
{
	u32 n = GetN(op);
	//TODO: set PR
	u32 retaddr=dec_set_pr();
	dec_DynamicSet(reg_r0+n,retaddr);
	dec_End(0xFFFFFFFF,BET_DynamicCall,true);
}
//jsr @<REG_N>
sh4dec(i0100_nnnn_0000_1011) 
{
	u32 n = GetN(op);

	//TODO: Set pr
	dec_set_pr();
	dec_DynamicSet(reg_r0+n);
	dec_End(0xFFFFFFFF,BET_DynamicCall,true);
}
//rts
sh4dec(i0000_0000_0000_1011)
{
	dec_DynamicSet(reg_pr);
	dec_End(0xFFFFFFFF,BET_DynamicRet,true);
}
//rte
sh4dec(i0000_0000_0010_1011)
{
	//TODO: Write SR, Check intr
	dec_write_sr(reg_ssr);
	Emit(shop_sync_sr);
	dec_DynamicSet(reg_spc);
	dec_End(0xFFFFFFFF,BET_DynamicIntr,true);
}
//trapa #<imm>
sh4dec(i1100_0011_iiii_iiii)
{
	//TODO: ifb
	dec_fallback(op);
	dec_DynamicSet(reg_nextpc);
	dec_End(0xFFFFFFFF,BET_DynamicJump,false);
}
//sleep
sh4dec(i0000_0000_0001_1011)
{
	//TODO: ifb
	dec_fallback(op);
	dec_DynamicSet(reg_nextpc);
	dec_End(0xFFFFFFFF,BET_DynamicJump,false);
}

//ldc.l @<REG_N>+,SR
sh4dec(i0100_nnnn_0000_0111)
{
	/*
	u32 sr_t;
	ReadMemU32(sr_t,r[n]);
	if (sh4_exept_raised)
		return;
	sr.SetFull(sr_t);
	r[n] += 4;
	if (UpdateSR())
	{
		//FIXME only if interrupts got on .. :P
		UpdateINTC();
	}*/
	dec_End(0xFFFFFFFF,BET_StaticIntr,false);
}

//ldc <REG_N>,SR
sh4dec(i0100_nnnn_0000_1110)
{
	u32 n = GetN(op);

	dec_write_sr((Sh4RegType)(reg_r0+n));
	Emit(shop_sync_sr);
	dec_End(0xFFFFFFFF,BET_StaticIntr,false);
}

//nop !
sh4dec(i0000_0000_0000_1001)
{
}

sh4dec(i1111_0011_1111_1101)
{
	//fpscr.SZ is bit 20
	Emit(shop_xor,reg_fpscr,reg_fpscr,mk_imm(1<<20));
	state.cpu.FSZ64=!state.cpu.FSZ64;
}

//frchg
sh4dec(i1111_1011_1111_1101)
{
	Emit(shop_xor,reg_fpscr,reg_fpscr,mk_imm(1<<21));
	Emit(shop_mov32,reg_old_fpscr,reg_fpscr);
	shil_param rmn;//null param
	Emit(shop_frswap,regv_xmtrx,regv_fmtrx,regv_xmtrx,0,rmn,regv_fmtrx);
}

//not-so-elegant, but avoids extra opcodes and temporalities ..
//rotcl
sh4dec(i0100_nnnn_0010_0100)
{
	u32 n = GetN(op);
	Sh4RegType rn=(Sh4RegType)(reg_r0+n);
	
	Emit(shop_rocl,rn,rn,reg_sr_T,0,shil_param(),reg_sr_T);
	/*
	Emit(shop_ror,rn,rn,mk_imm(31));
	Emit(shop_xor,rn,rn,reg_sr_T);              //Only affects last bit (swap part a)
	Emit(shop_xor,reg_sr_T,reg_sr_T,rn);        //srT -> rn
	Emit(shop_and,reg_sr_T,reg_sr_T,mk_imm(1)); //Keep only last bit
	Emit(shop_xor,rn,rn,reg_sr_T);              //Only affects last bit (swap part b)
	*/
}

//rotcr
sh4dec(i0100_nnnn_0010_0101)
{
	u32 n = GetN(op);
	Sh4RegType rn=(Sh4RegType)(reg_r0+n);

	Emit(shop_rocr,rn,rn,reg_sr_T,0,shil_param(),reg_sr_T);
	/*
	Emit(shop_xor,rn,rn,reg_sr_T);              //Only affects last bit (swap part a)
	Emit(shop_xor,reg_sr_T,reg_sr_T,rn);        //srT -> rn
	Emit(shop_and,reg_sr_T,reg_sr_T,mk_imm(1)); //Keep only last bit
	Emit(shop_xor,rn,rn,reg_sr_T);              //Only affects last bit (swap part b)

	Emit(shop_ror,rn,rn,mk_imm(1));
	*/
}
#endif

const Sh4RegType SREGS[] =
{
	reg_mach,
	reg_macl,
	reg_pr,
	reg_sgr,
	NoReg,
	reg_fpul,
	reg_fpscr,
	NoReg,

	NoReg,
	NoReg,
	NoReg,
	NoReg,
	NoReg,
	NoReg,
	NoReg,
	reg_dbr,
};

const Sh4RegType CREGS[] =
{
	reg_sr,
	reg_gbr,
	reg_vbr,
	reg_ssr,
	reg_spc,
	NoReg,
	NoReg,
	NoReg,

	reg_r0_Bank,
	reg_r1_Bank,
	reg_r2_Bank,
	reg_r3_Bank,
	reg_r4_Bank,
	reg_r5_Bank,
	reg_r6_Bank,
	reg_r7_Bank,
};

void dec_param(DecParam p,shil_param& r1,shil_param& r2, u32 op)
{
	switch(p)
	{
		//constants
	case PRM_PC_D8_x2:
		r1=mk_imm((state.cpu.rpc+4)+(GetImm8(op)<<1));
		break;

	case PRM_PC_D8_x4:
		r1=mk_imm(((state.cpu.rpc+4)&0xFFFFFFFC)+(GetImm8(op)<<2));
		break;
	
	case PRM_ZERO:
		r1= mk_imm(0);
		break;

	case PRM_ONE:
		r1= mk_imm(1);
		break;

	case PRM_TWO:
		r1= mk_imm(2);
		break;

	case PRM_TWO_INV:
		r1= mk_imm(~2);
		break;

	case PRM_ONE_F32:
		r1= mk_imm(0x3f800000);
		break;

	//imms
	case PRM_SIMM8:
		r1=mk_imm(GetSImm8(op));
		break;
	case PRM_UIMM8:
		r1=mk_imm(GetImm8(op));
		break;

	//direct registers
	case PRM_R0:
		r1=mk_reg(reg_r0);
		break;

	case PRM_RN:
		r1=mk_regi(reg_r0+GetN(op));
		break;

	case PRM_RM:
		r1=mk_regi(reg_r0+GetM(op));
		break;

	case PRM_FRN_SZ:
		if (state.cpu.FSZ64)
		{
			int rx=GetN(op)/2;
			if (GetN(op)&1)
				rx+=regv_xd_0;
			else
				rx+=regv_dr_0;

			r1=mk_regi(rx);
			break;
		}
	case PRM_FRN:
		r1=mk_regi(reg_fr_0+GetN(op));
		break;

	case PRM_FRM_SZ:
		if (state.cpu.FSZ64)
		{
			int rx=GetM(op)/2;
			if (GetM(op)&1)
				rx+=regv_xd_0;
			else
				rx+=regv_dr_0;

			r1=mk_regi(rx);
			break;
		}
	case PRM_FRM:
		r1=mk_regi(reg_fr_0+GetM(op));
		break;

	case PRM_FPUL:
		r1=mk_regi(reg_fpul);
		break;

	case PRM_FPN:	//float pair, 3 bits
		r1=mk_regi(regv_dr_0+GetN(op)/2);
		break;

	case PRM_FVN:	//float quad, 2 bits
		r1=mk_regi(regv_fv_0+GetN(op)/4);
		break;

	case PRM_FVM:	//float quad, 2 bits
		r1=mk_regi(regv_fv_0+(GetN(op)&0x3));
		break;

	case PRM_XMTRX:	//float matrix, 0 bits
		r1=mk_regi(regv_xmtrx);
		break;

	case PRM_FRM_FR0:
		r1=mk_regi(reg_fr_0+GetM(op));
		r2=mk_regi(reg_fr_0);
		break;

	case PRM_SR_T:
		r1=mk_regi(reg_sr_T);
		break;

	case PRM_SR_STATUS:
		r1=mk_regi(reg_sr_status);
		break;

	case PRM_SREG:	//FPUL/FPSCR/MACH/MACL/PR/DBR/SGR
		r1=mk_regi(SREGS[GetM(op)]);
		break;
	case PRM_CREG:	//SR/GBR/VBR/SSR/SPC/<RM_BANK>
		r1=mk_regi(CREGS[GetM(op)]);
		break;
	
	//reg/imm reg/reg
	case PRM_RN_D4_x1:
	case PRM_RN_D4_x2:
	case PRM_RN_D4_x4:
		{
			u32 shft=p-PRM_RN_D4_x1;
			r1=mk_regi(reg_r0+GetN(op));
			r2=mk_imm(GetImm4(op)<<shft);
		}
		break;

	case PRM_RN_R0:
		r1=mk_regi(reg_r0+GetN(op));
		r2=mk_regi(reg_r0);
		break;

	case PRM_RM_D4_x1:
	case PRM_RM_D4_x2:
	case PRM_RM_D4_x4:
		{
			u32 shft=p-PRM_RM_D4_x1;
			r1=mk_regi(reg_r0+GetM(op));
			r2=mk_imm(GetImm4(op)<<shft);
		}
		break;

	case PRM_RM_R0:
		r1=mk_regi(reg_r0+GetM(op));
		r2=mk_regi(reg_r0);
		break;

	case PRM_GBR_D8_x1:
	case PRM_GBR_D8_x2:
	case PRM_GBR_D8_x4:
		{
			u32 shft=p-PRM_GBR_D8_x1;
			r1=mk_regi(reg_gbr);
			r2=mk_imm(GetImm8(op)<<shft);
		}
		break;

	default:
		die("Non-supported parameter used");
	}
}

#define MASK_N_M 0xF00F
#define MASK_N   0xF0FF
#define MASK_NONE   0xFFFF

#define DIV0U_KEY 0x0019
#define DIV0S_KEY 0x2007
#define DIV1_KEY 0x3004
#define ROTCL_KEY 0x4024

Sh4RegType div_som_reg1;
Sh4RegType div_som_reg2;
Sh4RegType div_som_reg3;

u32 MatchDiv32(u32 pc , Sh4RegType &reg1,Sh4RegType &reg2 , Sh4RegType &reg3)
{

	u32 v_pc=pc;
	u32 match=1;
	for (int i=0;i<32;i++)
	{
		u16 opcode=ReadMem16(v_pc);
		v_pc+=2;
		if ((opcode&MASK_N)==ROTCL_KEY)
		{
			if (reg1==NoReg)
				reg1=(Sh4RegType)GetN(opcode);
			else if (reg1!=(Sh4RegType)GetN(opcode))
				break;
			match++;
		}
		else
		{
			//printf("DIV MATCH BROKEN BY: %s\n",OpDesc[opcode]->diss);
			break;
		}
		
		opcode=ReadMem16(v_pc);
		v_pc+=2;
		if ((opcode&MASK_N_M)==DIV1_KEY)
		{
			if (reg2==NoReg)
				reg2=(Sh4RegType)GetM(opcode);
			else if (reg2!=(Sh4RegType)GetM(opcode))
				break;
			
			if (reg2==reg1)
				break;

			if (reg3==NoReg)
				reg3=(Sh4RegType)GetN(opcode);
			else if (reg3!=(Sh4RegType)GetN(opcode))
				break;
			
			if (reg3==reg1)
				break;

			match++;
		}
		else
			break;
	}
	
	if (settings.dynarec.safemode)
		return 0;
	else
		return match;
}
bool MatchDiv32u(u32 op,u32 pc)
{
	div_som_reg1=NoReg;
	div_som_reg2=NoReg;
	div_som_reg3=NoReg;

	u32 match=MatchDiv32(pc+2,div_som_reg1,div_som_reg2,div_som_reg3);


	//log("DIV32U matched %d%% @ 0x%X\n",match*100/65,pc);
	if (match==65)
	{
		//DIV32U was perfectly matched :)
		return true;
	}
	else //no match ...
		return false;
}

bool MatchDiv32s(u32 op,u32 pc)
{
	u32 n = GetN(op);
	u32 m = GetM(op);

	div_som_reg1=NoReg;
	div_som_reg2=(Sh4RegType)m;
	div_som_reg3=(Sh4RegType)n;

	u32 match=MatchDiv32(pc+2,div_som_reg1,div_som_reg2,div_som_reg3);
	printf("DIV32S matched %d%% @ 0x%X\n",match*100/65,pc);
	
	if (match==65)
	{
		//DIV32S was perfectly matched :)
		printf("div32s %d/%d/%d\n",div_som_reg1,div_som_reg2,div_som_reg3);
		return true;
	}
	else //no match ...
	{
		/*
		printf("%04X\n",ReadMem16(pc-2));
		printf("%04X\n",ReadMem16(pc-0));
		printf("%04X\n",ReadMem16(pc+2));
		printf("%04X\n",ReadMem16(pc+4));
		printf("%04X\n",ReadMem16(pc+6));*/
		return false;
	}
}

/*
//This ended up too rare (and too hard to match)
bool MatchDiv0S_0(u32 pc)
{
	if (ReadMem16(pc+0)==0x233A && //XOR   r3,r3
		ReadMem16(pc+2)==0x2137 && //DIV0S r3,r1
		ReadMem16(pc+4)==0x322A && //SUBC  r2,r2
		ReadMem16(pc+6)==0x313A && //SUBC  r3,r1
		(ReadMem16(pc+8)&0xF00F)==0x2007) //DIV0S x,x
		return true;
	else
		return false;
}
*/

bool dec_generic(u32 op)
{
	DecMode mode;DecParam d;DecParam s;shilop natop;u32 e;
	if (OpDesc[op]->decode==0)
		return false;
	
	u64 inf=OpDesc[op]->decode;

	e=(u32)(inf>>32);
	mode=(DecMode)((inf>>24)&0xFF);
	d=(DecParam)((inf>>16)&0xFF);
	s=(DecParam)((inf>>8)&0xFF);
	natop=(shilop)((inf>>0)&0xFF);

	/*
	if ((op&0xF00F)==0x300E)
	{
		return false;
	}*/

	/*
	if (mode==DM_ADC)
		return false;
	*/

	bool transfer_64=false;
	if (op>=0xF000)
	{
		state.info.has_fpu=true;
		//return false;//FPU off for now
		if (state.cpu.FPR64 /*|| state.cpu.FSZ64*/)
			return false;

		if (state.cpu.FSZ64 && (d==PRM_FRN_SZ || d==PRM_FRM_SZ || s==PRM_FRN_SZ || s==PRM_FRM_SZ))
		{
			transfer_64=true;
		}
	}

	shil_param rs1,rs2,rs3,rd;

	dec_param(s,rs2,rs3,op);
	dec_param(d,rs1,rs3,op);

	switch(mode)
	{
	case DM_ReadSRF:
		Emit(shop_mov32,rs1,reg_sr_status);
		Emit(shop_or,rs1,rs1,reg_sr_T);
		break;

	case DM_WriteTOp:
		Emit(natop,reg_sr_T,rs1,rs2);
		break;

	case DM_DT:
		verify(natop==shop_sub);
		Emit(natop,rs1,rs1,rs2);
		Emit(shop_seteq,mk_reg(reg_sr_T),rs1,mk_imm(0));
		break;

	case DM_Shift:
		if (natop==shop_shl && e==1)
			Emit(shop_shr,mk_reg(reg_sr_T),rs1,mk_imm(31));
		else if (e==1)
			Emit(shop_and,mk_reg(reg_sr_T),rs1,mk_imm(1));

		Emit(natop,rs1,rs1,mk_imm(e));
		break;

	case DM_Rot:
		if (!(((s32)e>=0?e:-e)&0x1000))
		{
			if ((s32)e<0)
			{
				//left rotate
				Emit(shop_shr,mk_reg(reg_sr_T),rs2,mk_imm(31));
				e=-e;
			}
			else
			{
				//right rotate
				Emit(shop_and,mk_reg(reg_sr_T),rs2,mk_imm(1));
			}
		}
		e&=31;

		Emit(natop,rs1,rs2,mk_imm(e));
		break;

	case DM_BinaryOp://d=d op s
		if (e&1)
			Emit(natop,rs1,rs1,rs2,0,rs3);
		else
			Emit(natop,shil_param(),rs1,rs2,0,rs3);
		break;

	case DM_UnaryOp: //d= op s
		if (transfer_64 && natop==shop_mov32) 
			natop=shop_mov64;

		if (natop==shop_cvt_i2f_n && state.cpu.RoundToZero)
			natop=shop_cvt_i2f_z;

		if (e&1)
			Emit(natop,shil_param(),rs1);
		else
			Emit(natop,rs1,rs2);
		break;

	case DM_WriteM: //write(d,s)
		{
			//0 has no effect, so get rid of it
			if (rs3.is_imm() && rs3._imm==0)
				rs3=shil_param();

			state.info.has_writem=true;
			if (transfer_64) e=(s32)e*2;
			bool update_after=false;
			if ((s32)e<0)
			{
				if (rs1._reg!=rs2._reg) //reg shouldn't be updated if its written
				{
					Emit(shop_sub,rs1,rs1,mk_imm(-e));
				}
				else
				{
					verify(rs3.is_null());
					rs3=mk_imm(e);
					update_after=true;
				}
			}

			Emit(shop_writem,shil_param(),rs1,rs2,(s32)e<0?-e:e,rs3);

			if (update_after)
			{
				Emit(shop_sub,rs1,rs1,mk_imm(-e));
			}
		}
		break;

	case DM_ReadM:
		//0 has no effect, so get rid of it
		if (rs3.is_imm() && rs3._imm==0)
				rs3=shil_param();

		state.info.has_readm=true;
		if (transfer_64) e=(s32)e*2;

		Emit(shop_readm,rs1,rs2,shil_param(),(s32)e<0?-e:e,rs3);
		if ((s32)e<0)
		{
			if (rs1._reg!=rs2._reg)//the reg shouldn't be updated if it was just read.
				Emit(shop_add,rs2,rs2,mk_imm(-e));
		}
		break;

	case DM_fiprOp:
		{
			shil_param rdd=mk_regi(rs1._reg+3);
			Emit(natop,rdd,rs1,rs2);
		}
		break;

	case DM_EXTOP:
		{
			Emit(natop,rs1,rs2,mk_imm(e==1?0xFF:0xFFFF));
		}
		break;
	
	case DM_MUL:
		{
			shilop op;
			shil_param rd=mk_reg(reg_macl);
			shil_param rd2=shil_param();

			switch((s32)e)
			{
				case 16:  op=shop_mul_u16; break;
				case -16: op=shop_mul_s16; break;

				case -32: op=shop_mul_i32; break;

				case 64:  op=shop_mul_u64; rd2 = mk_reg(reg_mach); break;
				case -64: op=shop_mul_s64; rd2 = mk_reg(reg_mach); break;

				default:
					die("DM_MUL: Failed to classify opcode");
			}

			Emit(op,rd,rs1,rs2,0,shil_param(),rd2);
		}
		break;

	case DM_DIV0:
		{
			if (e==1)
			{
				if (MatchDiv32u(op,state.cpu.rpc))
				{
					verify(!state.cpu.is_delayslot);
					//div32u
					Emit(shop_div32u,mk_reg(div_som_reg1),mk_reg(div_som_reg1),mk_reg(div_som_reg2),0,shil_param(),mk_reg(div_som_reg3));
					
					Emit(shop_and,mk_reg(reg_sr_T),mk_reg(div_som_reg1),mk_imm(1));
					Emit(shop_shr,mk_reg(div_som_reg1),mk_reg(div_som_reg1),mk_imm(1));

					Emit(shop_div32p2,mk_reg(div_som_reg3),mk_reg(div_som_reg3),mk_reg(div_som_reg2),0,shil_param(reg_sr_T));
					
					//skip the aggregated opcodes
					state.cpu.rpc+=128;
					blk->guest_cycles+=CPU_RATIO*64;
				}
				else
				{
					//clear QM (bits 8,9)
					u32 qm=(1<<8)|(1<<9);
					Emit(shop_and,mk_reg(reg_sr_status),mk_reg(reg_sr_status),mk_imm(~qm));
					//clear T !
					Emit(shop_mov32,mk_reg(reg_sr_T),mk_imm(0));
				}
			}
			else
			{
				if (MatchDiv32s(op,state.cpu.rpc))
				{
					verify(!state.cpu.is_delayslot);
					//div32s
					Emit(shop_div32s,mk_reg(div_som_reg1),mk_reg(div_som_reg1),mk_reg(div_som_reg2),0,shil_param(),mk_reg(div_som_reg3));
					
					Emit(shop_and,mk_reg(reg_sr_T),mk_reg(div_som_reg1),mk_imm(1));
					Emit(shop_sar,mk_reg(div_som_reg1),mk_reg(div_som_reg1),mk_imm(1));

					Emit(shop_div32p2,mk_reg(div_som_reg3),mk_reg(div_som_reg3),mk_reg(div_som_reg2),0,shil_param(reg_sr_T));
					
					//skip the aggregated opcodes
					state.cpu.rpc+=128;
					blk->guest_cycles+=CPU_RATIO*64;
				}
				else
				{
					//sr.Q=r[n]>>31;
					//sr.M=r[m]>>31;
					//sr.T=sr.M^sr.Q;

					//This is nasty because there isn't a temp reg ..
					//VERY NASTY

					//Clear Q & M
					Emit(shop_and,mk_reg(reg_sr_status),mk_reg(reg_sr_status),mk_imm(~((1<<8)|(1<<9))));

					//sr.Q=r[n]>>31;
					Emit(shop_sar,mk_reg(reg_sr_T),rs1,mk_imm(31));
					Emit(shop_and,mk_reg(reg_sr_T),mk_reg(reg_sr_T),mk_imm(1<<8));
					Emit(shop_or,mk_reg(reg_sr_status),mk_reg(reg_sr_status),mk_reg(reg_sr_T));

					//sr.M=r[m]>>31;
					Emit(shop_sar,mk_reg(reg_sr_T),rs2,mk_imm(31));
					Emit(shop_and,mk_reg(reg_sr_T),mk_reg(reg_sr_T),mk_imm(1<<9));
					Emit(shop_or,mk_reg(reg_sr_status),mk_reg(reg_sr_status),mk_reg(reg_sr_T));

					//sr.T=sr.M^sr.Q;
					Emit(shop_xor,mk_reg(reg_sr_T),rs1,rs2);
					Emit(shop_shr,mk_reg(reg_sr_T),mk_reg(reg_sr_T),mk_imm(31));
				}
			}
		}
		break;

	case DM_ADC:
		{
			Emit(natop,rs1,rs1,rs2,0,mk_reg(reg_sr_T),mk_reg(reg_sr_T));
		}
		break;

	default:
		verify(false);
	}

	return true;
}

void dec_DecodeBlock(RuntimeBlockInfo* rbi,u32 max_cycles)
{
	blk=rbi;
	state.Setup(blk->addr,blk->fpu_cfg);
	ngen_GetFeatures(&state.ngen);
	
	blk->guest_opcodes=0;
	
	for(;;)
	{
		switch(state.NextOp)
		{
		case NDO_Delayslot:
			state.NextOp=state.DelayOp;
			state.cpu.is_delayslot=true;
			//there is no break here by design
		case NDO_NextOp:
			{
				if ( 
					( (blk->oplist.size() >= BLOCK_MAX_SH_OPS_SOFT) || (blk->guest_cycles >= max_cycles) )
					&& !state.cpu.is_delayslot
					)
				{
					dec_End(state.cpu.rpc,BET_StaticJump,false);
				}
				else
				{
					/*
					if (MatchDiv0S_0(state.cpu.rpc))
					{
						//can also be emitted as
						//sar   r2,31
						//subcs r1,1
						//in arm

						//r1=r1-sign bit
						//r2=sign mask
						Emit(shop_shl,mk_reg(reg_sr_T),mk_reg(reg_r2),mk_imm(31));
						Emit(shop_sar,mk_reg(reg_r2),mk_reg(reg_r2),mk_imm(31));
						Emit(shop_sub,mk_reg(reg_r1),mk_reg(reg_r1),mk_reg(reg_sr_T));
						blk->guest_cycles+=CPU_RATIO*4;
						state.cpu.rpc+=2*4;
						continue;
					}
					*/

					u32 op=ReadMem16(state.cpu.rpc);
					if (op==0 && state.cpu.is_delayslot)
					{
						printf("Delayslot 0 hack!\n");
					}
					else
					{
						blk->guest_opcodes++;
						if (op>=0xF000)
							blk->guest_cycles+=0;
						else
							blk->guest_cycles+=CPU_RATIO;

						verify(!(state.cpu.is_delayslot && OpDesc[op]->SetPC()));
						if (state.ngen.OnlyDynamicEnds || !OpDesc[op]->rec_oph)
						{
							if (state.ngen.InterpreterFallback || !dec_generic(op))
							{
								dec_fallback(op);
								if (OpDesc[op]->SetPC())
								{
									dec_DynamicSet(reg_nextpc);
									dec_End(0xFFFFFFFF,BET_DynamicJump,false);
								}
								if (OpDesc[op]->SetFPSCR() && !state.cpu.is_delayslot)
								{
									dec_End(state.cpu.rpc+2,BET_StaticJump,false);
								}
							}
							/*
							else if (state.info.has_readm || state.info.has_writem)
							{
								if (!state.cpu.is_delayslot)
								dec_End(state.cpu.rpc+2,BET_StaticJump,false);
							}
							*/
						}
						else
						{
							OpDesc[op]->rec_oph(op);
						}
					}
					state.cpu.rpc+=2;
				}
			}
			break;

		case NDO_Jump:
			die("Too old");
			state.NextOp=state.JumpOp;
			state.cpu.rpc=state.JumpAddr;
			break;

		case NDO_End:
			goto _end;
		}
	}

_end:
	blk->sh4_code_size=state.cpu.rpc-blk->addr;
	blk->NextBlock=state.NextAddr;
	blk->BranchBlock=state.JumpAddr;
	blk->BlockType=state.BlockType;

	verify(blk->oplist.size() <= BLOCK_MAX_SH_OPS_HARD);
	
#if HOST_OS == OS_WINDOWS
	switch(rbi->addr)
	{
	case 0x8C09ED16:
	case 0x8C0BA50E:
	case 0x8C0BA506:
	case 0x8C0BA526:
	case 0x8C224800:
		printf("HASH: %08X reloc %s\n",blk->addr,blk->hash(false,true));
		break;
	}
#endif

	//cycle tricks
	if (settings.dynarec.idleskip)
	{
		//Experimental hash-id based idle skip
		if (strstr(idle_hash,blk->hash(false,true)))
		{
			//printf("IDLESKIP: %08X reloc match %s\n",blk->addr,blk->hash(false,true));
			blk->guest_cycles=max_cycles*100;
		}
		else
		{
			//Small-n-simple idle loop detector :p
			if (state.info.has_readm && !state.info.has_writem && !state.info.has_fpu && blk->guest_opcodes<6)
			{
				if (blk->BlockType==BET_Cond_0 || (blk->BlockType==BET_Cond_1 && blk->BranchBlock<=blk->addr))
				{
					blk->guest_cycles*=3;
				}

				if (blk->BranchBlock==blk->addr)
				{
					blk->guest_cycles*=10;
				}
			}

			//if in syscalls area (ip.bin etc) skip fast :p
			if ((blk->addr&0x1FFF0000)==0x0C000000)
			{
				if (blk->addr&0x8000)
				{
					//ip.bin (boot loader/img etc)
					blk->guest_cycles*=15;
				}
				else
				{
					//syscalls
					blk->guest_cycles*=5;
				}
			}

			//blk->guest_cycles=5;
		}
	}
	else
	{
		blk->guest_cycles*=1.5;
	}

	//make sure we don't use wayy-too-many cycles
	blk->guest_cycles=min(blk->guest_cycles,max_cycles);
	//make sure we don't use wayy-too-few cycles
	blk->guest_cycles=max(1U,blk->guest_cycles);
	blk=0;
}

#endif