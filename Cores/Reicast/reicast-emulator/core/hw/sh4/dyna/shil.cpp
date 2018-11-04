/*
	Some WIP optimisation stuff and maby helper functions for shil
*/

#include <sstream>

#include "types.h"
#include "shil.h"
#include "decoder.h"
#include "hw/sh4/sh4_mem.h"
#include "blockmanager.h"

u32 RegisterWrite[sh4_reg_count];
u32 RegisterRead[sh4_reg_count];

void RegReadInfo(shil_param p,size_t ord)
{
	if (p.is_reg())
	{
		for (u32 i=0; i<p.count(); i++)
			RegisterRead[p._reg+i]=ord;
	}
}
void RegWriteInfo(shil_opcode* ops, shil_param p,size_t ord)
{
	if (p.is_reg())
	{
		for (u32 i=0; i<p.count(); i++)
		{
			if (RegisterWrite[p._reg+i]>=RegisterRead[p._reg+i] && RegisterWrite[p._reg+i]!=0xFFFFFFFF)	//if last read was before last write, and there was a last write
			{
				printf("DEAD OPCODE %d %d!\n",RegisterWrite[p._reg+i],ord);
				ops[RegisterWrite[p._reg+i]].Flow=1; //the last write was unused
			}
			RegisterWrite[p._reg+i]=ord;
		}
	}
}
u32 fallback_blocks;
u32 total_blocks;
u32 REMOVED_OPS;

bool isdst(shil_opcode* op,Sh4RegType rd)
{
	return (op->rd.is_r32() && op->rd._reg==rd) || (op->rd2.is_r32() && op->rd2._reg==rd);
}

//really hacky ~
//Isn't this now obsolete anyway ? (constprop pass should include it ..)
// -> constprop has some small stability issues still, not ready to be used on ip/bios fully yet
void PromoteConstAddress(RuntimeBlockInfo* blk)
{
	bool is_const=false;
	u32 value;

	total_blocks++;
	for (size_t i=0;i<blk->oplist.size();i++)
	{
		shil_opcode* op=&blk->oplist[i];
		if (is_const && op->op==shop_readm && op->rs1.is_reg() && op->rs1._reg==reg_r0)
		{
			u32 val=value;
			if (op->rs3.is_imm())
			{
				val+=op->rs3._imm;
				op->rs3=shil_param();
			}
			op->rs1=shil_param(FMT_IMM,val);
		}

		if (op->op==shop_mov32 && op->rs1.is_imm() && isdst(op,reg_r0) )
		{
			is_const=true;
			value=op->rs1._imm;
		}
		else if (is_const && (isdst(op,reg_r0) || op->op==shop_ifb || op->op==shop_sync_sr) )
			is_const=false;
	}
}

void sq_pref(RuntimeBlockInfo* blk, int i, Sh4RegType rt, bool mark)
{
	u32 data=0;
	for (int c=i-1;c>0;c--)
	{
		if (blk->oplist[c].op==shop_writem && blk->oplist[c].rs1._reg==rt)
		{
			if (blk->oplist[c].rs2.is_r32i() ||  blk->oplist[c].rs2.is_r32f() || blk->oplist[c].rs2.is_r64f() || blk->oplist[c].rs2.is_r32fv())
			{
				data+=blk->oplist[c].flags;
				if (mark)
					blk->oplist[c].flags2=0x1337;
			}
			else
				break;
		}

		if (blk->oplist[c].op==shop_pref || (blk->oplist[c].rd.is_reg() && blk->oplist[c].rd._reg==rt && blk->oplist[c].op!= shop_sub))
		{
			break;
		}

		if (data==32)
			break;
	}

	if (mark) return;

	if (data>=8)
	{
		blk->oplist[i].flags =0x1337;
		sq_pref(blk,i,rt,true);
		printf("SQW-WM match %d !\n",data);
	}
	else if (data)
	{
		printf("SQW-WM FAIL %d !\n",data);
	}
}

void sq_pref(RuntimeBlockInfo* blk)
{
	for (int i=0;i<blk->oplist.size();i++)
	{
		blk->oplist[i].flags2=0;
		if (blk->oplist[i].op==shop_pref)
			sq_pref(blk,i,blk->oplist[i].rs1._reg,false);
	}
}

//Read Groups
void rdgrp(RuntimeBlockInfo* blk)
{
	int started=-1;
	Sh4RegType reg;
	Sh4RegType regd;
	u32 stride;
	bool pend_add;
	u32 rdc;
	u32 addv;

	for (size_t i=0;i<blk->oplist.size();i++)
	{
		shil_opcode* op=&blk->oplist[i];
		op->Flow=0;

		if (started<0)
		{
			if (op->op==shop_readm &&  op->rd.type>=FMT_F32 && op->rs1.is_reg() && op->rs3.is_null())
			{
				started=i;
				stride=op->rd.count();
				reg=op->rs1._reg;
				regd=op->rd._reg;
				pend_add=true;
				rdc=1;
				addv=0;
			}
		}
		else
		{
			if (!pend_add && op->op==shop_readm && op->rd._reg==(regd+stride) && op->rs1.is_reg() && op->rs1._reg==reg  && op->rs3.is_null())
			{
				regd=(Sh4RegType)(regd+stride);
				pend_add=true;
				rdc++;
			}
			else if (pend_add && op->op==shop_add && op->rd._reg==op->rs1._reg && op->rs1.is_reg() && op->rs2.is_imm() && op->rs2._imm==(stride*4))
			{
				pend_add=false;
				addv+=op->rs2._imm;
			}
			else
			{
				u32 byts=rdc*stride*4;
				if (rdc!=1 && (byts==8 || byts==12 || byts==16 || byts==32 || byts==64))
				{
					verify(addv==byts || (pend_add && (addv+stride*4==byts)));

					blk->oplist[started].rd.type=byts==8?FMT_V2:byts==12?FMT_V3:
						byts==16?FMT_V4:byts==32?FMT_V8:FMT_V16;
					blk->oplist[started].flags=byts|0x80;
					if (stride==8)
						blk->oplist[started].flags|=0x100;
					blk->oplist[started].Flow=(rdc-1)*2 - (pend_add?1:0);
					blk->oplist[started+1].rs2._imm=addv;

					printf("Read Combination %d %d!\n",rdc,addv);
				}
				else if (rdc!=1)
				{
					printf("Read Combination failed %d %d %d\n",rdc,rdc*stride*4,addv);
				}
				started=-1;
			}
		}
	}

	
	for (size_t i=0;i<blk->oplist.size();i++)
	{
		shil_opcode* op=&blk->oplist[i];
		if (op->Flow)
		{
			blk->oplist.erase(blk->oplist.begin()+i+2,blk->oplist.begin()+i+2+op->Flow);
		}
	}
}
//Write Groups
void wtgrp(RuntimeBlockInfo* blk)
{
	int started=-1;
	Sh4RegType reg;
	Sh4RegType regd;
	u32 stride;
	bool pend_add;
	u32 rdc;
	u32 addv;

	for (size_t i=0;i<blk->oplist.size();i++)
	{
		shil_opcode* op=&blk->oplist[i];
		op->Flow=0;

		if (started<0)
		{
			if (op->op==shop_writem &&  op->rs2.type>=FMT_F32 && op->rs1.is_reg() && op->rs3.is_null())
			{
				started=i;
				stride=op->rd.count();
				reg=op->rs1._reg;
				regd=op->rs2._reg;
				pend_add=true;
				rdc=1;
				addv=0;
			}
		}
		else
		{
			if (!pend_add && op->op==shop_writem && op->rs2._reg==(regd-stride) && op->rs1.is_reg() && op->rs1._reg==reg  && op->rs3.is_null())
			{
				regd=(Sh4RegType)(regd-stride);
				pend_add=true;
				rdc++;
			}
			else if (pend_add && op->op==shop_sub && op->rd._reg==op->rs1._reg && op->rs1.is_reg() && op->rs1._reg==reg && op->rs2.is_imm() && op->rs2._imm==(stride*4))
			{
				pend_add=false;
				addv+=op->rs2._imm;
			}
			else
			{
				u32 byts=rdc*stride*4;
				u32 mask=byts/4;
				if (mask==3) mask=4;
				mask--;

				if (rdc!=1 /*&& (!(regd&mask))*/ && (byts==8 || byts==12 || byts==16 || byts==32 || byts==64))
				{
					verify(addv==byts || (pend_add && (addv+stride*4==byts)));

					blk->oplist[started].rs2.type=byts==8?FMT_V2:byts==12?FMT_V3:
						byts==16?FMT_V4:byts==32?FMT_V8:FMT_V16;
					blk->oplist[started].rs2._reg=regd;
					blk->oplist[started].rs3._imm=-(rdc-1)*stride*4;
					blk->oplist[started].rs3.type=FMT_IMM;
					blk->oplist[started].flags=byts|0x80;
					if (stride==8)
						blk->oplist[started].flags|=0x100;
					blk->oplist[started].Flow=(rdc-1)*2 - (pend_add?1:0);
					blk->oplist[started+1].rs2._imm=addv;

					printf("Write Combination %d %d!\n",rdc,addv);
				}
				else if (rdc!=1)
				{
					printf("Write Combination failed fr%d,%d, %d %d %d\n",regd,mask,rdc,rdc*stride*4,addv);
				}
				i=started;
				started=-1;
			}
		}
	}

	
	for (size_t i=0;i<blk->oplist.size();i++)
	{
		shil_opcode* op=&blk->oplist[i];
		if (op->Flow)
		{
			blk->oplist.erase(blk->oplist.begin()+i+2,blk->oplist.begin()+i+2+op->Flow);
		}
	}
}

bool ReadsPhy(shil_opcode* op, u32 phy)
{
	return true;
}

bool WritesPhy(shil_opcode* op, u32 phy)
{
	return true;
}

void rw_related(RuntimeBlockInfo* blk)
{
	u32 reg[sh4_reg_count]={0};

	u32 total=0;
	u32 memtotal=0;
	for (size_t i=0;i<blk->oplist.size();i++)
	{
		shil_opcode* op=&blk->oplist[i];
		op->Flow=0;


		if (op->op==shop_ifb || op->op==shop_sync_sr)
		{
			memset(reg,0,sizeof(reg));
		}
		if ( (op->op==shop_add || op->op==shop_sub) )
		{
			if (reg[op->rd._reg])
			{
				if (op->rs1.is_r32i() && op->rs1._reg==op->rd._reg && op->rs2.is_imm_s16())
				{
					//nothing !
				}
				else
					reg[op->rd._reg]=0;
			}
		}
		else 
		{

			if (op->op==shop_readm || op->op==shop_writem)
				if (op->rs1.is_r32i())
					memtotal++;

			if (op->op==shop_readm || op->op==shop_writem)
			{
				if (op->rs1.is_r32i())
				{
					if (op->rs3.is_imm_s16() || op->rs3.is_null())
					{
						reg[op->rs1._reg]++;
						if (reg[op->rs1._reg]>1)
							total++;
					}
					//else
						//reg[op->rs1._reg]=0;
				}
			}

			if (op->rd.is_reg() && reg[op->rd._reg]) 
				reg[op->rd._reg]=0;
			if (op->rd2.is_reg() && reg[op->rd2._reg]) 
				reg[op->rd2._reg]=0;
		}

	}

	if (memtotal)
	{
		u32 lookups=memtotal-total;

		//printf("rw_related total: %d/%d -- %.2f:1\n",total,memtotal,memtotal/(float)lookups);
	}
	else
	{
		//printf("rw_related total: none\n");
	}

	blk->memops=memtotal;
	blk->linkedmemops=total;
}


//constprop
void constprop(RuntimeBlockInfo* blk)
{
	u32 rv[16];
	bool isi[16]={0};

	for (size_t i=0;i<blk->oplist.size();i++)
	{
		shil_opcode* op=&blk->oplist[i];

		if (op->rs2.is_r32i() && op->rs2._reg<16 && isi[op->rs2._reg])
		{
			/*
				not all opcodes can take rs2 as constant
			*/
			if (op->op!=shop_readm && op->op!=shop_writem 
				&& op->op!=shop_mul_u16 && op->op!=shop_mul_s16 && op->op!=shop_mul_i32 
				&& op->op!=shop_mul_u64 && op->op!=shop_mul_s64 
				&& op->op!=shop_adc && op->op!=shop_sbc)
			{
				op->rs2.type=FMT_IMM;
				op->rs2._imm=rv[op->rs2._reg];

				if (op->op==shop_shld || op->op==shop_shad)
				{
					//convert em to mov/shl/shr

					printf("sh*d -> s*l !\n");
					s32 v=op->rs2._imm;

					if (v>=0)
					{
						//x86e->Emit(sl32,reg.mapg(op->rd),v);
						op->op=shop_shl;
						op->rs2._imm=0x1f & v;
					}
					else if (0==(v&0x1f))
					{
						if (op->op!=shop_shad)
						{
							//r[n]=0;
							//x86e->Emit(op_mov32,reg.mapg(op->rd),0);
							op->op=shop_mov32;
							op->rs1.type=FMT_IMM;
							op->rs1._imm=0;
							op->rs2.type=FMT_NULL;
						}
						else
						{
							//r[n]>>=31;
							//x86e->Emit(op_sar32,reg.mapg(op->rd),31);
							op->op=shop_sar;
							op->rs2._imm=31;
						}
					}
					else
					{
						//x86e->Emit(sr32,reg.mapg(op->rd),-v);
						if (op->op!=shop_shad)	
							op->op=shop_shr;
						else
							op->op=shop_sar;

						op->rs2._imm=0x1f & (-v);
					}
				}
			}
		}

		if (op->rs1.is_r32i() && op->rs1._reg<16 && isi[op->rs1._reg])
		{
			if ((op->op==shop_readm /*|| op->op==shop_writem*/) && (op->flags&0x7F)==4)
			{
				op->rs1.type=FMT_IMM;
				op->rs1._imm=rv[op->rs1._reg];

				if (op->rs3.is_imm())
				{
					op->rs1._imm+=op->rs3._imm;
					op->rs3.type=FMT_NULL;
				}
				printf("%s promotion: %08X\n",shop_readm==op->op?"shop_readm":"shop_writem",op->rs1._imm);
			}
			else if (op->op==shop_jdyn)
			{
				if (blk->BlockType==BET_DynamicJump || blk->BlockType==BET_DynamicCall)
				{
					blk->BranchBlock=rv[op->rs1._reg];
					if (op->rs2.is_imm())	
						blk->BranchBlock+=op->rs2._imm;;

					blk->BlockType=blk->BlockType==BET_DynamicJump?BET_StaticJump:BET_StaticCall;
					blk->oplist.erase(blk->oplist.begin()+i);
					i--;
					printf("SBP: %08X -> %08X!\n",blk->addr,blk->BranchBlock);
					continue;
				}
				else
				{
					printf("SBP: failed :(\n");
				}
			}
			else if (op->op==shop_mov32)
			{
				//handled later on !
			}
			else if (op->op==shop_add || op->op==shop_sub)
			{
									
				if (op->rs2.is_imm())
				{
					op->rs1.type=1;
					op->rs1._imm= op->op==shop_add ? 
						(rv[op->rs1._reg]+op->rs2._imm):
						(rv[op->rs1._reg]-op->rs2._imm);
					op->rs2.type=0;
					printf("%s -> mov32!\n",op->op==shop_add?"shop_add":"shop_sub");
					op->op=shop_mov32;
				}
				
				else if (op->op==shop_add && !op->rs2.is_imm())
				{
					u32 immy=rv[op->rs1._reg];
					op->rs1=op->rs2;
					op->rs2.type=1;
					op->rs2._imm=immy;
					printf("%s -> imm prm (%08X)!\n",op->op==shop_add?"shop_add":"shop_sub",immy);
				}
			}
			else
			{
				op->op=op->op;
			}
		}

		if (op->rd.is_r32i() && op->rd._reg<16) isi[op->rd._reg]=false;
		if (op->rd2.is_r32i() && op->rd2._reg<16) isi[op->rd._reg]=false;

		if (op->op==shop_mov32 && op->rs1.is_imm() && op->rd.is_r32i() && op->rd._reg<16)
		{
			isi[op->rd._reg]=true;
			rv[op->rd._reg]=op->rs1._imm;
		}

		//NOT WORKING
		//WE NEED PROPER PAGELOCKS
		if (op->op==shop_readm && op->rs1.is_imm() && op->rd.is_r32i() && op->rd._reg<16 && op->flags==0x4 && op->rs3.is_null())
		{
			u32 baddr=blk->addr&0x0FFFFFFF;

			if (/*baddr==0xC158400 &&*/ blk->addr/PAGE_SIZE == op->rs1._imm/PAGE_SIZE)
			{
				isi[op->rd._reg]=true;
				rv[op->rd._reg]= ReadMem32(op->rs1._imm);
				printf("IMM MOVE: %08X -> %08X\n",op->rs1._imm,rv[op->rd._reg]);

				op->op=shop_mov32;
				op->rs1._imm=rv[op->rd._reg];
			}
		}
	}

	rw_related(blk);
}

//read_v4m3z1
void read_v4m3z1(RuntimeBlockInfo* blk)
{
	
	int state=0;
	int st_sta=0;
	Sh4RegType reg_a;
	Sh4RegType reg_fb;

	for (size_t i=0;i<blk->oplist.size();i++)
	{
		shil_opcode* op=&blk->oplist[i];

		bool a=false,b=false;
		if ((i+6)>blk->oplist.size())
			break;

		if (state==0 && op->op==shop_readm && op->rd.is_r32f() && op->rs1.is_r32i() && op->rs3.is_null())
		{
			if (op->rd._reg==reg_fr_0 || op->rd._reg==reg_fr_4 || op->rd._reg==reg_fr_8 || op->rd._reg==reg_fr_12)
			{
				reg_a=op->rs1._reg;
				reg_fb=op->rd._reg;
				st_sta=i;
				goto _next_st;
			}
			goto _fail;
		}
		else if (state < 8 && state & 1 && op->op==shop_add && op->rd._reg==reg_a && op->rs1.is_reg() && op->rs1._reg==reg_a && op->rs2.is_imm() && op->rs2._imm==4)
		{
			if (state==7)
			{
				u32 start=st_sta;
				
				for (int j=0;j<6;j++)
				{
					blk->oplist.erase(blk->oplist.begin()+start);
				}

				i=start+1;
				op=&blk->oplist[start+0];
				op->op=shop_readm;
				op->flags=0x440;
				op->rd=shil_param(reg_fb==reg_fr_0?regv_fv_0:
								  reg_fb==reg_fr_4?regv_fv_4:
								  reg_fb==reg_fr_8?regv_fv_8:
								  reg_fb==reg_fr_12?regv_fv_12:reg_sr_T);
				op->rd2=shil_param();

				op->rs1=shil_param(reg_a);
				op->rs2=shil_param();
				op->rs3=shil_param();

				op=&blk->oplist[start+1];
				op->op=shop_add;
				op->flags=0;
				op->rd=shil_param(reg_a);
				op->rd2=shil_param();

				op->rs1=shil_param(reg_a);
				op->rs2=shil_param(FMT_IMM,16);
				op->rs3=shil_param();

				goto _end;
			}
			else
				goto _next_st;
		}
		else if (state >1 && 
			op->op==shop_readm && op->rd.is_r32f() && op->rd._reg==(reg_fb+state/2) && op->rs1.is_r32i() && op->rs1._reg==reg_a && op->rs3.is_null())
		{
			goto _next_st;
		}
		else if ((a=(op->op==shop_mov32 && op->rd._reg==(reg_fb+3) && op->rs1.is_imm() && (op->rs1._imm==0x3f800000 /*|| op->rs1._imm==0*/))) ||
			    (b=(i>7 && op[-7].op==shop_mov32 && op[-7].rd._reg==(reg_fb+3) && op[-7].rs1.is_imm() && (op[-7].rs1._imm==0x3f800000 /*|| op[-7].rs1._imm==0*/))) )
		{
			if (state==6)
			{
				if (b)
					st_sta--;
				if (a)
					printf("NOT B\b");
				u32 start=st_sta;
								
				for (int j=0;j<5;j++)
				{
					blk->oplist.erase(blk->oplist.begin()+start);
				}
				
				i=start+1;
				op=&blk->oplist[start+0];
				op->op=shop_readm;
				op->flags=0x431;
				op->rd=shil_param(reg_fb==reg_fr_0?regv_fv_0:
								  reg_fb==reg_fr_4?regv_fv_4:
								  reg_fb==reg_fr_8?regv_fv_8:
								  reg_fb==reg_fr_12?regv_fv_12:reg_sr_T);
				op->rd2=shil_param();

				op->rs1=shil_param(reg_a);
				op->rs2=shil_param();
				op->rs3=shil_param();

				op=&blk->oplist[start+1];
				op->op=shop_add;
				op->flags=0;
				op->rd=shil_param(reg_a);
				op->rd2=shil_param();

				op->rs1=shil_param(reg_a);
				op->rs2=shil_param(FMT_IMM,12);
				op->rs3=shil_param();

				goto _end;
			}
			else
				goto _fail;
		}
		else
			goto _fail;


		die("wth");

_next_st:
		state ++;
		continue;

_fail:
		if (state)
			i=st_sta;
_end:
		state=0;

	}

}

//dejcond
void dejcond(RuntimeBlockInfo* blk)
{
	u32 rv[16];
	bool isi[16]={0};

	if (!blk->has_jcond) return;

	bool found=false;
	u32 jcondp=0;

	for (size_t i=0;i<blk->oplist.size();i++)
	{
		shil_opcode* op=&blk->oplist[i];

		if (found)
		{
			if ((op->rd.is_reg() && op->rd._reg==reg_sr_T) ||  op->op==shop_ifb)
			{
				found=false;
			}
		}

		if (op->op==shop_jcond)
		{
			found=true;
			jcondp=i;
		}
	}

	if (found)
	{
		blk->has_jcond=false;
		blk->oplist.erase(blk->oplist.begin()+jcondp);
	}
}

//detect bswaps and talk about them
void enswap(RuntimeBlockInfo* blk)
{
	Sh4RegType r;
	int state=0;
	
	for (size_t i=0;i<blk->oplist.size();i++)
	{
		shil_opcode* op=&blk->oplist[i];

		op->Flow=0;

		if (state==0 && op->op==shop_swaplb)
		{
			if (op->rd._reg==op->rs1._reg)
			{
				state=1;
				r=op->rd._reg;
				op->Flow=1;
				continue;
			}
			else
			{
				printf("bswap -- wrong regs\n");
			}
		}

		if (state==1 && op->op==shop_ror && op->rs2.is_imm() && op->rs2._imm==16 && 
			op->rs1._reg==r)
		{
			if (op->rd._reg==r)
			{
				state=2;
				op->Flow=1;
				continue;
			}
			else
			{
				printf("bswap -- wrong regs\n");
			}
		}

		if (state==2 && op->op==shop_swaplb && op->rs1._reg==r)
		{
			if (op->rd._reg!=r)
			{
				printf("oops?\n");
			}
			else
			{
				printf("SWAPM!\n");
			}
			op->Flow=1;
			state=0;
		}

	}
}

//enjcond
//this is a normally slower
//however, cause of reg alloc stuff in arm, this
//speeds up access to SR_T (pc_dyn is stored in reg, not mem)
//This is temporary til that limitation is fixed on the reg alloc logic
void enjcond(RuntimeBlockInfo* blk)
{
	u32 rv[16];
	bool isi[16]={0};

	if (!blk->has_jcond && (blk->BlockType==BET_Cond_0||blk->BlockType==BET_Cond_1))
	{
		shil_opcode jcnd;

		jcnd.op=shop_jcond;
		jcnd.rs1=shil_param(reg_sr_T);
		jcnd.rd=shil_param(reg_pc_dyn);
		jcnd.flags=0;
		blk->oplist.push_back(jcnd);
		blk->has_jcond=true;
	}
}


//"links" consts to each other
void constlink(RuntimeBlockInfo* blk)
{
	Sh4RegType def=NoReg;
	s32 val;

	for (size_t i=0;i<blk->oplist.size();i++)
	{
		shil_opcode* op=&blk->oplist[i];

		if (op->op!=shop_mov32)
			def=NoReg;
		else
		{

			if (def!=NoReg && op->rs1.is_imm() && op->rs1._imm==val)
			{
				op->rs1=shil_param(def);
			}
			else if (def==NoReg && op->rs1.is_imm() && op->rs1._imm==0)
			{
				//def=op->rd._reg;
				val=op->rs1._imm;
			}
		}
	}
}


void srt_waw(RuntimeBlockInfo* blk)
{
	bool found=false;
	u32 srtw=0;

	for (size_t i=0;i<blk->oplist.size();i++)
	{
		shil_opcode* op=&blk->oplist[i];

		if (found)
		{
			if ((op->rs1.is_reg() && op->rs1._reg==reg_sr_T)
				|| (op->rs2.is_reg() && op->rs2._reg==reg_sr_T)
				|| (op->rs3.is_reg() && op->rs3._reg==reg_sr_T)
				|| op->op==shop_ifb)
			{
				found=false;
			}
		}

		if (op->rd.is_reg() && op->rd._reg==reg_sr_T && op->rd2.is_null())
		{
			if (found)
			{
				blk->oplist.erase(blk->oplist.begin()+srtw);
				i--;
			}

			found=true;
			srtw=i;
		}
	}

}

//Simplistic Write after Write without read pass to remove (a few) dead opcodes
//Seems to be working
void AnalyseBlock(RuntimeBlockInfo* blk)
{

	u32 st[sh4_reg_count]={0};
	/*
	for (size_t i=0;i<blk->oplist.size();i++)
	{
		shil_opcode* op=&blk->oplist[i];
		
		if (op->rs1.is_reg() && st[op->rs1._reg]==0)
			st[op->rs1._reg]=1;

		if (op->rs2.is_reg() && st[op->rs2._reg]==0)
			st[op->rs2._reg]=1;

		if (op->rs3.is_reg() && st[op->rs3._reg]==0)
			st[op->rs3._reg]=1;

		if (op->rd.is_reg())
			st[op->rd._reg]|=2;

		if (op->rd2.is_reg())
			st[op->rd2._reg]|=2;
	}

	if (st[reg_sr_T]&1)
	{
		printf("BLOCK: %08X\n",blk->addr);

		puts("rin: ");

		for (int i=0;i<sh4_reg_count;i++)
		{
			if (st[i]&1)
				printf("%s ",name_reg(i).c_str());
		}

		puts("\nrout: ");

		for (int i=0;i<sh4_reg_count;i++)
		{
			if (st[i]&2)
				printf("%s ",name_reg(i).c_str());
		}

		puts("\nr-ns: ");

		for (int i=0;i<sh4_reg_count;i++)
		{
			if (st[i]==2)
				printf("%s ",name_reg(i).c_str());
		}


		puts("\n");
	}
	*/
	if (settings.dynarec.unstable_opt)
		sq_pref(blk);
	//constprop(blk); // crashes on ip
#if HOST_CPU==CPU_X86
//	rdgrp(blk);
//	wtgrp(blk);
	//constprop(blk);
	
#endif
	bool last_op_sets_flags=!blk->has_jcond && blk->oplist.size() > 0 && 
		blk->oplist[blk->oplist.size()-1].rd._reg==reg_sr_T;

	srt_waw(blk);
	constlink(blk);
	//dejcond(blk);
	if (last_op_sets_flags)
	{
		shilop op= blk->oplist[blk->oplist.size()-1].op;
		if (op == shop_test || op==shop_seteq || op==shop_setab || op==shop_setae
			|| op == shop_setge || op==shop_setgt)
			;
		else
			last_op_sets_flags=false;
	}
	if (!last_op_sets_flags)
		enjcond(blk);
	//read_v4m3z1(blk);
	//rw_related(blk);

	return;	//disbled to be on the safe side ..
	memset(RegisterWrite,-1,sizeof(RegisterWrite));
	memset(RegisterRead,-1,sizeof(RegisterRead));

	total_blocks++;
	for (size_t i=0;i<blk->oplist.size();i++)
	{
		shil_opcode* op=&blk->oplist[i];
		op->Flow=0;
		if (op->op==shop_ifb)
		{
			fallback_blocks++;
			return;
		}

		RegReadInfo(op->rs1,i);
		RegReadInfo(op->rs2,i);
		RegReadInfo(op->rs3,i);

		RegWriteInfo(&blk->oplist[0],op->rd,i);
		RegWriteInfo(&blk->oplist[0],op->rd2,i);
	}

	for (size_t i=0;i<blk->oplist.size();i++)
	{
		if (blk->oplist[i].Flow)
		{
			blk->oplist.erase(blk->oplist.begin()+i);
			REMOVED_OPS++;
			i--;
		}
	}

	int affregs=0;
	for (int i=0;i<16;i++)
	{
		if (RegisterWrite[i]!=0)
		{
			affregs++;
			//printf("r%02d:%02d ",i,RegisterWrite[i]);
		}
	}
	//printf("<> %d\n",affregs);

	//printf("%d FB, %d native, %.2f%% || %d removed ops!\n",fallback_blocks,total_blocks-fallback_blocks,fallback_blocks*100.f/total_blocks,REMOVED_OPS);
	//printf("\nBlock: %d affecter regs %d c\n",affregs,blk->guest_cycles);
}

void UpdateFPSCR();
bool UpdateSR();
#include "hw/sh4/modules/ccn.h"
#include "ngen.h"
#include "hw/sh4/sh4_core.h"
#include "hw/sh4/sh4_mmr.h"


#define SHIL_MODE 1
#include "shil_canonical.h"

#define SHIL_MODE 4
#include "shil_canonical.h"

//#define SHIL_MODE 2
//#include "shil_canonical.h"

#if FEAT_SHREC != DYNAREC_NONE
#define SHIL_MODE 3
#include "shil_canonical.h"
#endif

string name_reg(u32 reg)
{
	stringstream ss;

	if (reg>=reg_fr_0 && reg<=reg_xf_15)
		ss << "f" << (reg-16);
	else if (reg<=reg_r15)
		ss << "r" << reg;
	else if (reg == reg_sr_T)
		ss << "sr.T";
	else if (reg == reg_fpscr)
		ss << "fpscr";
	else if (reg == reg_sr_status)
		ss << "sr";
	else
		ss << "s" << reg;

	return ss.str();
}
string dissasm_param(const shil_param& prm, bool comma)
{
	stringstream ss;

	if (!prm.is_null() && comma)
			ss << ", ";

	if (prm.is_imm())
	{	
		if (prm.is_imm_s8())
			ss  << (s32)prm._imm ;
		else
			ss << "0x" << hex << prm._imm;
	}
	else if (prm.is_reg())
	{
		if (!prm.is_r32i())
			ss << "f" << (prm._reg-16);
		else if (prm._reg<=reg_r15)
			ss << "r" << prm._reg;
		else if (prm._reg == reg_sr_T)
			ss << "sr.T";
		else if (prm._reg == reg_fpscr)
			ss << "fpscr";
		else if (prm._reg == reg_sr_status)
			ss << "sr";
		else
			ss << "s" << prm._reg;
			

		if (prm.count()>1)
		{
			ss << "v" << prm.count();
		}
	}

	return ss.str();
}

string shil_opcode::dissasm()
{
	stringstream ss;
	ss << shilop_str[op] << " " << dissasm_param(rd,false) << dissasm_param(rd2,true) << " <= " << dissasm_param(rs1,false) << dissasm_param(rs2,true) << dissasm_param(rs3,true);
	return ss.str();
}

const char* shil_opcode_name(int op)
{
	return shilop_str[op];
}