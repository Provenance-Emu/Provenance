#include "types.h"

#if FEAT_SHREC == DYNAREC_JIT && HOST_CPU == CPU_X86
#include "rec_x86_ngen.h"
#include "hw/sh4/sh4_mmr.h"
#include "hw/sh4/sh4_rom.h"

void ngen_Bin(shil_opcode* op,x86_opcode_class natop,bool has_imm=true,bool has_wb=true)
{
	//x86e->Emit(op_mov32,EAX,op->rs1.reg_ptr());

	verify(reg.IsAllocg(op->rs1._reg));
	verify(reg.IsAllocg(op->rd._reg));

	if (has_wb && reg.mapg(op->rs1)!=reg.mapg(op->rd))
	{
		x86e->Emit(op_mov32,reg.mapg(op->rd),reg.mapg(op->rs1));
	}

	if (has_imm && op->rs2.is_imm())
	{
		x86e->Emit(natop,has_wb?reg.mapg(op->rd):reg.mapg(op->rs1),op->rs2._imm);
	}
	else if (op->rs2.is_r32i())
	{
		verify(reg.IsAllocg(op->rs2._reg));
		
		x86e->Emit(natop,has_wb?reg.mapg(op->rd):reg.mapg(op->rs1),reg.mapg(op->rs2));
	}
	else
	{
		printf("%d \n",op->rs1.type);
		verify(false);
	}
}

void ngen_fp_bin(shil_opcode* op,x86_opcode_class natop)
{
	verify(reg.IsAllocf(op->rs1));
	verify(reg.IsAllocf(op->rs2));
	verify(reg.IsAllocf(op->rd));

	if (op->rd._reg!=op->rs1._reg)
		x86e->Emit(op_movss,reg.mapf(op->rd),reg.mapf(op->rs1));

	if (op->rs2.is_r32f())
	{
		x86e->Emit(natop,reg.mapf(op->rd),reg.mapf(op->rs2));
	}
	else
	{
		printf("%d \n",op->rs2.type);
		verify(false);
	}
//	verify(has_wb);
		//x86e->Emit(op_movss,op->rd.reg_ptr(),XMM0);
}
void ngen_Unary(shil_opcode* op,x86_opcode_class natop)
{
	verify(reg.IsAllocg(op->rs1));
	verify(reg.IsAllocg(op->rd));

	if (reg.mapg(op->rs1)!=reg.mapg(op->rd))
		x86e->Emit(op_mov32,reg.mapg(op->rd),reg.mapg(op->rs1));

	x86e->Emit(natop,reg.mapg(op->rd));
}

void* _vmem_read_const(u32 addr,bool& ismem,u32 sz);

u32 ngen_CC_BytesPushed;
void ngen_CC_Start(shil_opcode* op)
{
	ngen_CC_BytesPushed=0;
}
void ngen_CC_Param(shil_opcode* op,shil_param* par,CanonicalParamType tp)
{
	switch(tp)
	{
		//push the contents
		case CPT_u32:
		case CPT_f32:
			if (par->is_reg())
			{
				if (reg.IsAllocg(*par))
					x86e->Emit(op_push32,reg.mapg(*par));
				else if (reg.IsAllocf(*par))
				{
					x86e->Emit(op_sub32,ESP,4);
					x86e->Emit(op_movss,x86_mrm(ESP), reg.mapf(*par));
				}
				else
				{
					die("Must not happen !\n");
					x86e->Emit(op_push32,x86_ptr(par->reg_ptr()));
				}
			}
			else if (par->is_imm())
				x86e->Emit(op_push,par->_imm);
			else
				die("invalid combination");
			ngen_CC_BytesPushed+=4;
			break;
		//push the ptr itself
		case CPT_ptr:
			verify(par->is_reg());

			x86e->Emit(op_push,(unat)par->reg_ptr());

			for (u32 ri=0; ri<(*par).count(); ri++)
			{
				if (reg.IsAllocf(*par,ri))
				{
					x86e->Emit(op_sub32,ESP,4);
					x86e->Emit(op_movss,x86_mrm(ESP),reg.mapfv(*par,ri));
				}
				else
				{
					verify(!reg.IsAllocAny((Sh4RegType)(par->_reg+ri)));
				}
			}

			
			ngen_CC_BytesPushed+=4;
			break;

		//store from EAX
		case CPT_u64rvL:
		case CPT_u32rv:
			if (reg.IsAllocg(*par))
				x86e->Emit(op_mov32,reg.mapg(*par),EAX);
			/*else if (reg.IsAllocf(*par))
				x86e->Emit(op_movd_xmm_from_r32,reg.mapf(*par),EAX);*/
			else
				die("Must not happen!\n");
			break;

		case CPT_u64rvH:
			if (reg.IsAllocg(*par))
				x86e->Emit(op_mov32,reg.mapg(*par),EDX);
			else
				die("Must not happen!\n");
			break;

		//Store from ST(0)
		case CPT_f32rv:
			verify(reg.IsAllocf(*par));
			x86e->Emit(op_fstp32f,x86_ptr(par->reg_ptr()));
			x86e->Emit(op_movss,reg.mapf(*par),x86_ptr(par->reg_ptr()));
			break;
		
	}
}

void ngen_CC_Call(shil_opcode*op,void* function)
{
	reg.FreezeXMM();
	x86e->Emit(op_call,x86_ptr_imm(function));
	reg.ThawXMM();
}
void ngen_CC_Finish(shil_opcode* op)
{
	x86e->Emit(op_add32,ESP,ngen_CC_BytesPushed);
}

extern u32 vrml_431;
#ifdef PROF2

extern u32 srmls,srmlu,srmlc;
extern u32 rmls,rmlu;
extern u32 wmls,wmlu;
extern u32 vrd;
#endif


void DYNACALL VERIFYME(u32 addr)
{
	verify((addr>>26)==0x38);
}

/*

	ReadM
	I8          GAI1    [m]
	I16         GAI2    [m]
	I32         GAI4    [m]
	F32         GA4     [m]
	F32v2       RA4     [m,m]
	F32v4       RA4     [m,m,m,m]
	F32v4r3i1   RA4     [m,m,m,1.0]
	F32v4r3i0   RA4     [m,m,m,0.0]

	WriteM
	I8          GA1
	I16         GA2
	I32         GA4
	F32         GA4
	F32v2       SA
	F32v4
	F32v4s3
	F32v4s4


	//10
	R S8    B,M
	R S16   B,M
	R I32   B,M
	R F32   B,M
	R F32v2 B{,M}

	//13
	W I8    B,M
	W I16   B,M
	W I32   B,S,M
	W F32   B,S,M
	W F32v2 B,S{,M}
*/

extern void* mem_code[3][2][5];

void ngen_opcode(RuntimeBlockInfo* block, shil_opcode* op,x86_block* x86e, bool staging, bool optimise)
{
	switch(op->op)
		{
		case shop_readm:
			{
				void* fuct=0;
				bool isram=false;
				verify(op->rs1.is_imm() || op->rs1.is_r32i());
	
				verify(op->rs1.is_imm() || reg.IsAllocg(op->rs1));
				verify(op->rs3.is_null() || op->rs3.is_imm() || reg.IsAllocg(op->rs3));
				
				for (u32 i=0;i<op->rd.count();i++)
				{
					verify(reg.IsAllocAny((Sh4RegType)(op->rd._reg+i)));
				}

				u32 size=op->flags&0x7f;

				if (op->rs1.is_imm())
				{
					if (prof.enable) x86e->Emit(op_add32,&prof.counters.shil.readm_const,1);
					void* ptr=_vmem_read_const(op->rs1._imm,isram,size);
					if (isram)
					{
#ifdef PROF2
						x86e->Emit(op_add32,&srmlu,1);
#endif
						if (size==1)
							x86e->Emit(op_movsx8to32,EAX,ptr);
						else if (size==2)
							x86e->Emit(op_movsx16to32,EAX,ptr);
						else if (size==4)
						{
							x86e->Emit(op_mov32,EAX,ptr);
							//this is a pretty good sieve, but its not perfect.
							//whitelisting is much better, but requires side channel data
							//Page locking w/ invalidation is another strategy we can try (leads to 'excessive'
							//compiling. Maybe a mix of both ?), its what the mainline nulldc uses
							if (optimise)
							{
								if (staging && !is_s8(*(u32*)ptr) && abs((int)op->rs1._imm-(int)block->addr)<=1024)
								{
									x86_Label* _same=x86e->CreateLabel(false,8);
									x86e->Emit(op_cmp32,EAX,*(u32*)ptr);
									x86e->Emit(op_je,_same);
									x86e->Emit(op_and32,&op->flags,~0x40000000);
									x86e->MarkLabel(_same);

									op->flags|=0x40000000;
								}
								else if (!staging && op->flags & 0x40000000)
								{
									x86_Label* _same=x86e->CreateLabel(false,8);
									x86e->Emit(op_cmp32,EAX,*(u32*)ptr);
									x86e->Emit(op_je,_same);
									x86e->Emit(op_int3);
									x86e->MarkLabel(_same);
#ifdef PROF2
									x86e->Emit(op_add32,&srmlc,1);
#endif
								}
							}
						}
						else if (size==8)
						{
							x86e->Emit(op_mov32,EAX,ptr);
							x86e->Emit(op_mov32,EDX,(u8*)ptr+4);
						}
						else
						{
							die("Invalid mem read size");
						}
					}
					else
					{
#ifdef PROF2
						x86e->Emit(op_add32,&srmls,1);
#endif
						x86e->Emit(op_mov32,ECX,op->rs1._imm);
						fuct=ptr;
					}
				}
				else
				{
					x86e->Emit(op_mov32,ECX,reg.mapg(op->rs1));
					if (op->rs3.is_imm())
					{
						x86e->Emit(op_add32,ECX,op->rs3._imm);
						if (prof.enable) x86e->Emit(op_add32,&prof.counters.shil.readm_reg_imm,1);
					}
					else if (op->rs3.is_r32i())
					{
						x86e->Emit(op_add32,ECX,reg.mapg(op->rs3));
						if (prof.enable) x86e->Emit(op_add32,&prof.counters.shil.readm_reg_reg,1);
					}
					else if (!op->rs3.is_null())
					{
						die("invalid rs3");
					}
					else
						if (prof.enable) x86e->Emit(op_add32,&prof.counters.shil.readm_reg,1);
#if 0
					if (op->flags==0x431 || op->flags==0x440)
					{
						verify(!reg.IsAllocAny(op->rd));
						verify(!reg.IsAllocAny((Sh4RegType)(op->rd._reg+1)));
						verify(!reg.IsAllocAny((Sh4RegType)(op->rd._reg+2)));
						verify(!reg.IsAllocAny((Sh4RegType)(op->rd._reg+3)));

						x86e->Emit(op_add32,&vrml_431,1);
						x86e->Emit(op_mov32,EDX,ECX);
						x86e->Emit(op_and32,EDX,0x1FFFFFFF);
						x86e->Emit(op_movups,XMM0,x86_mrm(EDX,x86_ptr(virt_ram_base)));
						x86e->Emit(op_movaps,op->rd.reg_ptr(),XMM0);

						if (op->flags==0x431)
							x86e->Emit(op_mov32,op->rd.reg_ptr()+3,0x3f800000);
						else if (op->flags==0x430)
							x86e->Emit(op_mov32,op->rd.reg_ptr()+3,0);

						break;
					}
					
					bool vect=op->flags&0x80;

					if (vect)
					{
						u32 sz=size;
						//x86e->Emit(op_add32,&cvld,sz/(op->flags&0x100?8:4));
						x86e->Emit(op_add32,&vrml_431,sz/(op->flags&0x100?8:4)*2);
						verify(sz==8 || sz==12 || sz==16 || sz==32 || sz==64);

						void** vmap,** funct;
						_vmem_get_ptrs(4,false,&vmap,&funct);
						x86e->Emit(op_mov32,EAX,ECX);
						x86e->Emit(op_shr32,EAX,24);
						x86e->Emit(op_mov32,EAX,x86_mrm(EAX,sib_scale_4,vmap));

						x86e->Emit(op_test32,EAX,~0x7F);
						x86e->Emit(op_jz,x86_ptr_imm::create(op->flags));
						x86e->Emit(op_xchg32,ECX,EAX);
						x86e->Emit(op_shl32,EAX,ECX);
						x86e->Emit(op_shr32,EAX,ECX);
						x86e->Emit(op_and32,ECX,~0x7F);

						int i=0;
						for (i=0;(i+16)<=sz;i+=16)
						{
							x86e->Emit(op_movups,XMM0,x86_mrm(EAX,ECX,sib_scale_1,x86_ptr::create(i)));
							if (op->rd._reg&3)
								x86e->Emit(op_movups,op->rd.reg_ptr()+i/4,XMM0);
							else
								x86e->Emit(op_movaps,op->rd.reg_ptr()+i/4,XMM0);
						}
						for (;(i+8)<=sz;i+=8)
						{
							x86e->Emit(op_movlps,XMM0,x86_mrm(EAX,ECX,sib_scale_1,x86_ptr::create(i)));
							x86e->Emit(op_movlps,op->rd.reg_ptr()+i/4,XMM0);
						}
						for (;(i+4)<=sz;i+=4)
						{
							x86e->Emit(op_movss,XMM0,x86_mrm(EAX,ECX,sib_scale_1,x86_ptr::create(i)));
							x86e->Emit(op_movss,op->rd.reg_ptr()+i/4,XMM0);
						}

						verify(i==sz);

						break;

					}
					
					if (optimise)
					{
						if (staging || op->flags&0x80000000)
						{

							//opt disabled for now
							op->flags|=0x80000000;

							x86_Label* _ram=x86e->CreateLabel(false,8);
							void** vmap,** funct;
							_vmem_get_ptrs(4,false,&vmap,&funct);
							x86e->Emit(op_mov32,EAX,ECX);
							x86e->Emit(op_shr32,EAX,24);
							x86e->Emit(op_mov32,EAX,x86_mrm(EAX,sib_scale_4,vmap));

							x86e->Emit(op_test32,EAX,~0x7F);
							x86e->Emit(op_jnz,_ram);

							if (staging)
							{
								x86e->Emit(op_and32,&op->flags,~0x80000000);
							}
							else
							{
								//x86e->Emit(op_int3);
							}

							x86e->MarkLabel(_ram);
						}

						if ( !staging)
						{
							if (op->flags & 0x80000000)
							{
#ifdef PROF2
								x86e->Emit(op_add32,&rmlu,1);
#endif
								if (true)
								{
									u32 sz=op->flags&0x7f;
									if (sz!=8)
									{
										x86e->Emit(op_mov32,EDX,ECX);
										x86e->Emit(op_and32,EDX,0x1FFFFFFF);
										if (sz==1)
										{
											x86e->Emit(op_movsx8to32,EAX,x86_mrm(EDX,x86_ptr(virt_ram_base)));
										}
										else if (sz==2)
										{
											x86e->Emit(op_movsx16to32,EAX,x86_mrm(EDX,x86_ptr(virt_ram_base)));
										}
										else if (sz==4)
										{
											x86e->Emit(op_mov32,EAX,x86_mrm(EDX,x86_ptr(virt_ram_base)));
										}
										isram=true;
									}
								}

							}
#ifdef PROF2
							else
							{
								x86e->Emit(op_add32,&rmls,1);
							}
#endif
						}
					}
#endif
#if 1
					//new code ...
					//yay ...

					int Lsz=0;
					int sz=size;
					if (sz==2) Lsz=1;
					if (sz==4 && op->rd.is_r32i()) Lsz=2;
					if (sz==4 && op->rd.is_r32f()) Lsz=3;
					if (sz==8) Lsz=4;

					//x86e->Emit(op_int3);

					reg.FreezeXMM();
					x86e->Emit(op_call,x86_ptr_imm(mem_code[0][0][Lsz]));
					reg.ThawXMM();

					if (Lsz <= 2)
					{
						x86e->Emit(op_mov32, reg.mapg(op->rd), EAX);
					}
					else
					{
						x86e->Emit(op_movss, reg.mapfv(op->rd, 0), XMM0);
						if (Lsz == 4)
							x86e->Emit(op_movss, reg.mapfv(op->rd, 1), XMM1);
					}
					break;
#endif
				}

				if (size<=8)
				{

					if (size==8 && optimise)
					{
						die("unreachable");
#ifdef OPTIMIZATION_GRAVEYARD
						verify(op->rd.count()==2 && reg.IsAllocf(op->rd,0) && reg.IsAllocf(op->rd,1));

						x86e->Emit(op_mov32,EDX,ECX);
						x86e->Emit(op_and32,EDX,0x1FFFFFFF);
						x86e->Emit(op_movss,reg.mapfv(op->rd,0),x86_mrm(EDX,x86_ptr(virt_ram_base)));
						x86e->Emit(op_movss,reg.mapfv(op->rd,1),x86_mrm(EDX,x86_ptr(4+virt_ram_base)));
						break;
#endif
					}
					if (!isram)
					{
						reg.FreezeXMM();
						switch(size)
						{
						case 1:
							if (!fuct) fuct=reinterpret_cast<void*>(&ReadMem8);
							x86e->Emit(op_call,x86_ptr_imm(fuct));
							x86e->Emit(op_movsx8to32,EAX,EAX);
							break;
						case 2:
							if (!fuct) fuct=reinterpret_cast<void*>(&ReadMem16);
							x86e->Emit(op_call,x86_ptr_imm(fuct));
							x86e->Emit(op_movsx16to32,EAX,EAX);
							break;
						case 4:
							if (!fuct) fuct=reinterpret_cast<void*>(&ReadMem32);
							x86e->Emit(op_call,x86_ptr_imm(fuct));
							break;
						case 8:
							if (!fuct) fuct=reinterpret_cast<void*>(&ReadMem64);
							x86e->Emit(op_call,x86_ptr_imm(fuct));
							break;
						default:
							verify(false);
						}
						reg.ThawXMM();
					}

					if (size!=8)
					{
						if (reg.IsAllocg(op->rd))
							x86e->Emit(op_mov32,reg.mapg(op->rd),EAX);
						else if (reg.IsAllocf(op->rd))
							x86e->Emit(op_movd_xmm_from_r32,reg.mapf(op->rd),EAX);
						else
							x86e->Emit(op_mov32,op->rd.reg_ptr(),EAX);
					}
					else
					{
						verify(op->rd.count()==2 && reg.IsAllocf(op->rd,0) && reg.IsAllocf(op->rd,1));
						
						x86e->Emit(op_movd_xmm_from_r32,reg.mapfv(op->rd,0),EAX);
						x86e->Emit(op_movd_xmm_from_r32,reg.mapfv(op->rd,1),EDX);
					}

				}
			}
			break;

		case shop_writem:
			{
				u32 size=op->flags&0x7f;
				verify(reg.IsAllocg(op->rs1) || op->rs1.is_imm());
				
				verify(op->rs2.is_r32() || (op->rs2.count()==2 && reg.IsAllocf(op->rs2,0) && reg.IsAllocf(op->rs2,1)));

				if (op->rs1.is_imm() && size<=4)
				{
					if (prof.enable) x86e->Emit(op_add32,&prof.counters.shil.readm_const,1);
					bool isram;
					void* ptr=_vmem_read_const(op->rs1._imm,isram,size);
					if (isram)
					{
						if (size<=2)
							x86e->Emit(op_mov32,EAX,reg.mapg(op->rs2));
						if (size==1)
							x86e->Emit(op_mov8,ptr,EAX);
						else if (size==2)
							x86e->Emit(op_mov16,ptr,EAX);
						else if (size==4)
						{
							if (op->rs2.is_r32i())
								x86e->Emit(op_mov32,ptr,reg.mapg(op->rs2));
							else
								x86e->Emit(op_movss,ptr,reg.mapf(op->rs2));
						}

						else if (size==8)
						{
							die("A");
						}
						else
							die("Invalid mem read size");

						goto done_writem;
					}
					else
						x86e->Emit(op_mov32,ECX,op->rs1._imm);
				}
				else
				{
					x86e->Emit(op_mov32,ECX,reg.mapg(op->rs1));
				}
			
				if (op->rs3.is_imm())
				{
					x86e->Emit(op_add32,ECX,op->rs3._imm);
				}
				else if (op->rs3.is_r32i())
				{
					verify(reg.IsAllocg(op->rs3));
					x86e->Emit(op_add32,ECX,reg.mapg(op->rs3));
				}
				else if (!op->rs3.is_null())
				{
					printf("rs3: %08X\n",op->rs3.type);
					die("invalid rs3");
				}

#if 1
				//new code ...
				//yay ...

				int Lsz=0;
				int sz=size;
				if (sz==2) Lsz=1;
				if (sz==4 && op->rs2.is_r32i()) Lsz=2;
				if (sz==4 && op->rs2.is_r32f()) Lsz=3;
				if (sz==8) Lsz=4;

				//x86e->Emit(op_int3);
				//if (Lsz==0)
				{

					if (Lsz<=2)
						x86e->Emit(op_mov32,EDX,reg.mapg(op->rs2));
					else 
					{
						x86e->Emit(op_movss,XMM0,reg.mapfv(op->rs2,0));
						if (Lsz==4)
							x86e->Emit(op_movss,XMM1,reg.mapfv(op->rs2,1));
					}

					reg.FreezeXMM();
					x86e->Emit(op_call,x86_ptr_imm(mem_code[2][1][Lsz]));
					reg.ThawXMM();

					break;
				}
#endif
#ifdef OPTIMIZATION_GRAVEYARD
				die("woohoo");
				/*
				if (size==8 && optimise)
				{
					verify(!reg.IsAllocAny(op->rd));
					verify(!reg.IsAllocAny((Sh4RegType)(op->rd._reg+1)));

					x86e->Emit(op_mov32,EDX,ECX);
					x86e->Emit(op_and32,EDX,0x1FFFFFFF);
					x86e->Emit(op_movlps,XMM0,op->rs2.reg_ptr());
					x86e->Emit(op_movlps,x86_mrm(EDX,x86_ptr(virt_ram_base)),XMM0);
					break;
				}*/

				bool vect=op->flags&0x80;

				if (!vect && size<=8)
				{
					if (size!=8)
					{
						if (reg.IsAllocg(op->rs2))
						{
							x86e->Emit(op_mov32,EDX,reg.mapg(op->rs2));
						}
						else if (reg.IsAllocf(op->rs2))
						{
							x86e->Emit(op_movd_xmm_to_r32,EDX,reg.mapf(op->rs2));
						}
						else
						{
							die("Must not happen\n");
						}
					}
					else
					{
						verify(op->rs2.count()==2 && reg.IsAllocf(op->rs2,0) && reg.IsAllocf(op->rs2,1));
						
						x86e->Emit(op_sub32,ESP,8);
						//[ESP+4]=rs2[1]//-4 +8= +4
						//[ESP+0]=rs2[0]//-8 +8 = 0
						x86e->Emit(op_movss,x86_mrm(ESP,x86_ptr::create(+4)),reg.mapfv(op->rs2,1));
						x86e->Emit(op_movss,x86_mrm(ESP,x86_ptr::create(-0)),reg.mapfv(op->rs2,0));
					}
				


					if (optimise)
					{
						if (staging || op->flags&0x80000000)
						{

							//opt disabled for now
							op->flags|=0x80000000;
							x86_Label* _ram=x86e->CreateLabel(false,8);
							void** vmap,** funct;
							_vmem_get_ptrs(4,false,&vmap,&funct);
							x86e->Emit(op_mov32,EAX,ECX);
							x86e->Emit(op_shr32,EAX,24);
							x86e->Emit(op_mov32,EAX,x86_mrm(EAX,sib_scale_4,vmap));

							x86e->Emit(op_test32,EAX,~0x7F);
							x86e->Emit(op_jnz,_ram);

							if (staging)
							{
								x86e->Emit(op_and32,&op->flags,~0x80000000);
							}
							else
							{
								//x86e->Emit(op_int3);
							}

							x86e->MarkLabel(_ram);
						}


						if (!staging)
						{
							if (op->flags & 0x80000000)
							{
#ifdef PROF2
								x86e->Emit(op_add32,&wmlu,1);
#endif
								if (false && size<4)
								{
									x86e->Emit(op_mov32,EAX,ECX);
									x86e->Emit(op_and32,EAX,0x1FFFFFFF);

									if (size==1)
									{
										x86e->Emit(op_mov8,x86_mrm(EAX,x86_ptr(virt_ram_base)),EDX);
									}
									else if (size==2)
									{
										x86e->Emit(op_mov16,x86_mrm(EAX,x86_ptr(virt_ram_base)),EDX);
									}
									else if (size==4)
									{
										x86e->Emit(op_mov32,x86_mrm(EAX,x86_ptr(virt_ram_base)),EAX);
									}
									break;
								}

							}
#ifdef PROF2
							else
								x86e->Emit(op_add32,&wmls,1);
#endif
						}
					}
				}

				if (vect)
				{
					u32 sz=op->flags&0x7f;
					x86e->Emit(op_add32,&vrml_431,sz/(op->flags&0x100?8:4)*5);
					verify(sz==8 || sz==12 || sz==16 || sz==32 || sz==64);

					void** vmap,** funct;
					_vmem_get_ptrs(4,false,&vmap,&funct);
					x86e->Emit(op_mov32,EAX,ECX);
					x86e->Emit(op_shr32,EAX,24);
					x86e->Emit(op_mov32,EAX,x86_mrm(EAX,sib_scale_4,vmap));

					x86e->Emit(op_test32,EAX,~0x7F);
					x86e->Emit(op_jz,x86_ptr_imm::create(op->flags));
					x86e->Emit(op_xchg32,ECX,EAX);
					x86e->Emit(op_shl32,EAX,ECX);
					x86e->Emit(op_shr32,EAX,ECX);
					x86e->Emit(op_and32,ECX,~0x7F);

					u32 i=0;
					for (; (i+16)<=sz; i+=16)
					{
						if (op->rs2._reg&3)
							x86e->Emit(op_movups,XMM0,op->rs2.reg_ptr()+i/4);
						else
							x86e->Emit(op_movaps,XMM0,op->rs2.reg_ptr()+i/4);

						x86e->Emit(op_movups,x86_mrm(EAX,ECX,sib_scale_1,x86_ptr::create(i)),XMM0);
					}
					for (; (i+8)<=sz; i+=8)
					{
						x86e->Emit(op_movlps,XMM0,op->rs2.reg_ptr()+i/4);
						x86e->Emit(op_movlps,x86_mrm(EAX,ECX,sib_scale_1,x86_ptr::create(i)),XMM0);
					}
					for (; (i+4)<=sz; i+=4)
					{
						x86e->Emit(op_movss,XMM0,op->rs2.reg_ptr()+i/4);
						x86e->Emit(op_movss,x86_mrm(EAX,ECX,sib_scale_1,x86_ptr::create(i)),XMM0);
					}

					verify(i==sz);
				}
				else
				{

					reg.FreezeXMM();
					switch(size)
					{
					case 1:
						x86e->Emit(op_call,x86_ptr_imm(&WriteMem8));
						break;
					case 2:
						x86e->Emit(op_call,x86_ptr_imm(&WriteMem16));
						break;
					case 4:
						x86e->Emit(op_call,x86_ptr_imm(&WriteMem32));
						break;
					case 8:
						x86e->Emit(op_call,x86_ptr_imm(&WriteMem64));
						break;
					default:
						verify(false);
					}
					reg.ThawXMM();
				}
#endif
			}
			done_writem:
			break;

		case shop_ifb:
			{
				/*
				//reg alloc should be flushed here. Add Check
				for (int i=0;i<sh4_reg_count;i++)
				{
					verify(!reg.IsAllocAny((Sh4RegType)i));
				}*/

				if (op->rs1._imm)
				{
					x86e->Emit(op_mov32,&next_pc,op->rs2._imm);
				}
				x86e->Emit(op_mov32,ECX,op->rs3._imm);
#ifdef PROF2
				x86e->Emit(op_add32,&OpDesc[op->rs3._imm]->fallbacks,1);
				x86e->Emit(op_adc32,((u8*)&OpDesc[op->rs3._imm]->fallbacks)+4,0);
#endif
				x86e->Emit(op_call,x86_ptr_imm(OpDesc[op->rs3._imm]->oph));
			}
			break;

		case shop_jdyn:
			{
				
				verify(reg.IsAllocg(op->rs1));
				verify(reg.IsAllocg(op->rd));

				x86e->Emit(op_mov32,reg.mapg(op->rd),reg.mapg(op->rs1));
				if (op->rs2.is_imm())
				{
					x86e->Emit(op_add32,reg.mapg(op->rd),op->rs2._imm);
				}
				//x86e->Emit(op_mov32,op->rd.reg_ptr(),EAX);
			}
			break;

		case shop_jcond:
			{
				verify(block->has_jcond);
				verify(reg.IsAllocg(op->rs1));
				verify(reg.IsAllocg(op->rd));

				x86e->Emit(op_mov32,reg.mapg(op->rd),reg.mapg(op->rs1));
				//x86e->Emit(op_mov32,op->rd.reg_ptr(),EAX);
			}
			break;
			
		case shop_mov64:
			{
				verify(op->rd.is_r64());
				verify(op->rs1.is_r64());
				
				verify(reg.IsAllocf(op->rs1,0) && reg.IsAllocf(op->rs1,1));
				verify(reg.IsAllocf(op->rd,0) && reg.IsAllocf(op->rd,1));
				
				
				x86e->Emit(op_movaps,reg.mapfv(op->rd,0),reg.mapfv(op->rs1,0));
				x86e->Emit(op_movaps,reg.mapfv(op->rd,1),reg.mapfv(op->rs1,1));
			}
			break;

		case shop_mov32:
			{
				verify(op->rd.is_r32());

				if (op->rs1.is_imm())
				{
					if (op->rd.is_r32i())
					{
						x86e->Emit(op_mov32,reg.mapg(op->rd),op->rs1._imm);
				//		x86e->Emit(op_add32,&rdmt[4],1);
					}
					else
					{
						//verify(!reg.IsAllocAny(op->rd));
						x86e->Emit(op_mov32,EAX,op->rs1._imm);
						x86e->Emit(op_movd_xmm_from_r32,reg.mapf(op->rd),EAX);
					//	x86e->Emit(op_add32,&rdmt[5],1);
					}
				}
				else if (op->rs1.is_r32())
				{
					u32 type=0;

					if (reg.IsAllocf(op->rd))
						type|=1;
					
					if (reg.IsAllocf(op->rs1))
						type|=2;
				//	x86e->Emit(op_add32,&rdmt[type],1);
					switch(type)
					{
					case 0: //reg=reg
						if (reg.mapg(op->rd) != reg.mapg(op->rs1))
							x86e->Emit(op_mov32,reg.mapg(op->rd),reg.mapg(op->rs1));

						break;

					case 1: //xmm=reg
						x86e->Emit(op_movd_xmm_from_r32,reg.mapf(op->rd),reg.mapg(op->rs1));
						break;

					case 2: //reg=xmm
						x86e->Emit(op_movd_xmm_to_r32,reg.mapg(op->rd),reg.mapf(op->rs1));
						break;

					case 3: //xmm=xmm
						if (reg.mapf(op->rd) != reg.mapf(op->rs1))
							x86e->Emit(op_movss,reg.mapf(op->rd),reg.mapf(op->rs1));
						else
							printf("Renamed fmov !\n");
						break;
						
					}
				}
				else
				{
					die("Invalid mov32 size");
				}
				
			}
			break;

//if CANONICAL_TEST is defined all opcodes use the C-based  canonical implementation !
//#define CANONICAL_TEST 1
#ifndef CANONICAL_TEST
		case shop_and:	ngen_Bin(op,op_and32);		break;
		case shop_or:	ngen_Bin(op,op_or32);		break;
		case shop_xor:	ngen_Bin(op,op_xor32);		break;
		case shop_add:	ngen_Bin(op,op_add32);		break;
		case shop_sub:	ngen_Bin(op,op_sub32);		break;
		case shop_ror:	ngen_Bin(op,op_ror32);	break;

		case shop_shl:
		case shop_shr:
		case shop_sar:
			{
				x86_opcode_class opcd[]={op_shl32,op_shr32,op_sar32};
				ngen_Bin(op,opcd[op->op-shop_shl]);
			}
			break;

		case shop_rocr:
		case shop_rocl:
			{
				x86e->Emit(op_sar32,reg.mapg(op->rs2),1);
				x86e->Emit(op->op==shop_rocr?op_rcr32:op_rcl32,reg.mapg(op->rd),1);
				x86e->Emit(op_rcl32,reg.mapg(op->rd2),1);
			}
			break;

		case shop_test:
		case shop_seteq:
		case shop_setge:
		case shop_setgt:
		case shop_setae:
		case shop_setab:
			{		
				x86_opcode_class opcls1=op->op==shop_test?op_test32:op_cmp32;
				x86_opcode_class opcls2[]={op_setz,op_sete,op_setge,op_setg,op_setae,op_seta };
				ngen_Bin(op,opcls1,true,false);
				x86e->Emit(opcls2[op->op-shop_test],AL);
				x86e->Emit(op_movzx8to32,reg.mapg(op->rd),AL);
			}
			break;

		case shop_adc:
			{
				x86e->Emit(op_sar32,reg.mapg(op->rs3),1);
				if (reg.mapg(op->rd)!=reg.mapg(op->rs1))
					x86e->Emit(op_mov32,reg.mapg(op->rd),reg.mapg(op->rs1));
				x86e->Emit(op_adc32,reg.mapg(op->rd),reg.mapg(op->rs2));
				x86e->Emit(op_rcl32,reg.mapg(op->rd2),1);
			}
			break;

			//rd=rs1<<rs2
		case shop_shad:
		case shop_shld:
			{
				verify(reg.IsAllocg(op->rs1));
				verify(op->rs2.is_imm() || reg.IsAllocg(op->rs2));
				verify(reg.IsAllocg(op->rd));

				x86_opcode_class sl32=op->op==shop_shad?op_sal32:op_shl32;
				x86_opcode_class sr32=op->op==shop_shad?op_sar32:op_shr32;

				if (reg.mapg(op->rd)!=reg.mapg(op->rs1))
					x86e->Emit(op_mov32,reg.mapg(op->rd),reg.mapg(op->rs1));

				if (op->rs2.is_imm())
				{
					die("sh*d: no imms please\n");
				}
				else
				{
					x86e->Emit(op_mov32,ECX,reg.mapg(op->rs2));

					x86_Label* _exit=x86e->CreateLabel(false,8);
					x86_Label* _neg=x86e->CreateLabel(false,8);
					x86_Label* _nz=x86e->CreateLabel(false,8);

					x86e->Emit(op_cmp32,reg.mapg(op->rs2),0);
					x86e->Emit(op_js,_neg);
					{
						//>=0
						//r[n]<<=sf;
						x86e->Emit(sl32,reg.mapg(op->rd),ECX);
						x86e->Emit(op_jmp,_exit);
					}
					x86e->MarkLabel(_neg);
					x86e->Emit(op_test32,reg.mapg(op->rs2),0x1f);
					x86e->Emit(op_jnz,_nz);
					{
						//1fh==0
						if (op->op!=shop_shad)
						{
							//r[n]=0;
							x86e->Emit(op_mov32,reg.mapg(op->rd),0);
						}
						else
						{
							//r[n]>>=31;
							x86e->Emit(op_sar32,reg.mapg(op->rd),31);
						}
						x86e->Emit(op_jmp,_exit);
					}
					x86e->MarkLabel(_nz);
					{
						//<0
						//r[n]>>=(-sf);
						x86e->Emit(op_neg32,ECX);
						x86e->Emit(sr32,reg.mapg(op->rd),ECX);
					}
					x86e->MarkLabel(_exit);
				}
			}
			break;

		case shop_swaplb:
			{
				if (reg.mapg(op->rd)!=reg.mapg(op->rs1))
					x86e->Emit(op_mov32,reg.mapg(op->rd),reg.mapg(op->rs1));
				x86e->Emit(op_ror16,reg.mapg(op->rd),8);
			}
			break;


		case shop_neg:	ngen_Unary(op,op_neg32);	break;
		case shop_not:	ngen_Unary(op,op_not32);	break;

		
		case shop_sync_sr:
			{
				//reg alloc should be flushed here. Add Check
				for (int i=0;i<8;i++)
				{
					verify(!reg.IsAllocAny((Sh4RegType)(reg_r0+i)));
					verify(!reg.IsAllocAny((Sh4RegType)(reg_r0_Bank+i)));
				}

				verify(!reg.IsAllocAny(reg_old_sr_status));
				verify(!reg.IsAllocAny(reg_sr_status));

				//reg alloc should be flushed here, add checks
				x86e->Emit(op_call,x86_ptr_imm(UpdateSR));
			}
			break;

		case shop_sync_fpscr:
			{
				//reg alloc should be flushed here. Add Check
				for (int i=0;i<16;i++)
				{
					verify(!reg.IsAllocAny((Sh4RegType)(reg_fr_0+i)));
					verify(!reg.IsAllocAny((Sh4RegType)(reg_xf_0+i)));
				}

				verify(!reg.IsAllocAny(reg_old_fpscr));
				verify(!reg.IsAllocAny(reg_fpscr));


				//reg alloc should be flushed here, add checks
				x86e->Emit(op_call,x86_ptr_imm(UpdateFPSCR));
			}
			break;


		case shop_mul_u16:
		case shop_mul_s16:
		case shop_mul_i32:
		case shop_mul_u64:
		case shop_mul_s64:
			{
				verify(reg.IsAllocg(op->rs1));
				verify(reg.IsAllocg(op->rs2));
				verify(reg.IsAllocg(op->rd));

				x86_opcode_class opdt[]={op_movzx16to32,op_movsx16to32,op_mov32,op_mov32,op_mov32};
				x86_opcode_class opmt[]={op_mul32,op_mul32,op_mul32,op_mul32,op_imul32};
				//only the top 32 bits are different on signed vs unsigned

				u32 opofs=op->op-shop_mul_u16;

				x86e->Emit(opdt[opofs],EAX,reg.mapg(op->rs1));
				x86e->Emit(opdt[opofs],EDX,reg.mapg(op->rs2));
				
				x86e->Emit(opmt[opofs],EDX);
				x86e->Emit(op_mov32,reg.mapg(op->rd),EAX);

				if (op->op>=shop_mul_u64)
					x86e->Emit(op_mov32,reg.mapg(op->rd2),EDX);
			}
			break;


			//fpu
		case shop_fadd:
		case shop_fsub:
		case shop_fmul:
		case shop_fdiv:
			{
				verify(reg.IsAllocf(op->rs1));
				verify(reg.IsAllocf(op->rs2));
				verify(reg.IsAllocf(op->rd));

				const x86_opcode_class opcds[]= { op_addss, op_subss, op_mulss, op_divss };
				ngen_fp_bin(op,opcds[op->op-shop_fadd]);
			}
			break;

		case shop_fabs:
			{
				verify(reg.IsAllocf(op->rs1));
				verify(reg.IsAllocf(op->rd));

				static DECL_ALIGN(16) u32 AND_ABS_MASK[4] = { 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF };

				verify(op->rd._reg==op->rs1._reg);
				x86e->Emit(op_pand,reg.mapf(op->rd),AND_ABS_MASK);
			}
			break;

		case shop_fneg:
			{
				verify(reg.IsAllocf(op->rs1));
				verify(reg.IsAllocf(op->rd));

				static DECL_ALIGN(16) u32 XOR_NEG_MASK[4] = { 0x80000000, 0x80000000, 0x80000000, 0x80000000 };

				verify(op->rd._reg==op->rs1._reg);
				x86e->Emit(op_pxor,reg.mapf(op->rd),XOR_NEG_MASK);
			}
			break;

		case shop_fsca:
			{
				verify(op->rs1.is_r32i());

				//verify(op->rd.is_vector); //double ? vector(2) ?

				verify(reg.IsAllocg(op->rs1));
				verify(reg.IsAllocf(op->rd,0) && reg.IsAllocf(op->rd,1));

				//sin/cos
				x86e->Emit(op_movzx16to32,EAX,reg.mapg(op->rs1));
				x86e->Emit(op_movss,reg.mapfv(op->rd,0),x86_mrm(EAX,sib_scale_8,x86_ptr(&sin_table->u[0])));
				x86e->Emit(op_movss,reg.mapfv(op->rd,1),x86_mrm(EAX,sib_scale_8,x86_ptr(&sin_table->u[1])));
			}
			break;

		case shop_fipr:
			{
				//rd=rs1*rs2 (vectors)
//				verify(!reg.IsAllocAny(op->rs1));
//				verify(!reg.IsAllocAny(op->rs2));
				verify(reg.IsAllocf(op->rd));
								
				verify(op->rs1.is_r32fv()==4);
				verify(op->rs2.is_r32fv()==4);
				verify(op->rd.is_r32());

				if (sse_3)
				{
					x86_reg xmm=reg.mapf(op->rd);

					x86e->Emit(op_movaps ,xmm,op->rs1.reg_ptr());
					x86e->Emit(op_mulps ,xmm,op->rs2.reg_ptr());
													//xmm0={a0				,a1				,a2				,a3}
					x86e->Emit(op_haddps,xmm,xmm);	//xmm0={a0+a1			,a2+a3			,a0+a1			,a2+a3}
					x86e->Emit(op_haddps,xmm,xmm);	//xmm0={(a0+a1)+(a2+a3) ,(a0+a1)+(a2+a3),(a0+a1)+(a2+a3),(a0+a1)+(a2+a3)}
				}
				else
				{
					x86_reg xmm=reg.mapf(op->rd);

					x86e->Emit(op_movaps ,xmm,op->rs1.reg_ptr());
					x86e->Emit(op_mulps ,xmm,op->rs2.reg_ptr());
					x86e->Emit(op_movhlps ,XMM1,xmm);
					x86e->Emit(op_addps ,xmm,XMM1);
					x86e->Emit(op_movaps ,XMM1,xmm);
					x86e->Emit(op_shufps ,XMM1,XMM1,1);
					x86e->Emit(op_addss ,xmm,XMM1);
				}
			}
			break;

		case shop_fsqrt:
			{
				verify(reg.IsAllocf(op->rs1));
				verify(reg.IsAllocf(op->rd));

				//rd=sqrt(rs1)
				x86e->Emit(op_sqrtss ,reg.mapf(op->rd),reg.mapf(op->rs1));
				//x86e->Emit(op_movss ,op->rd.reg_ptr(),XMM0);
			}
			break;
			
		case shop_ftrv:
			{
#ifdef PROF2
				x86e->Emit(op_add32,&vrd,16);
#endif
				verify(!reg.IsAllocAny(op->rs1));
				verify(!reg.IsAllocAny(op->rs2));
				verify(!reg.IsAllocAny(op->rd));

				//rd(vector)=rs1(vector)*rs2(matrix)
				verify(op->rd.is_r32fv()==4);
				verify(op->rs1.is_r32fv()==4);
				verify(op->rs2.is_r32fv()==16);

#if 1
				//load the vector ..
				if (sse_2)
				{
					x86e->Emit(op_movaps ,XMM3,op->rs1.reg_ptr());  //xmm0=vector
					x86e->Emit(op_pshufd ,XMM0,XMM3,0);             //xmm0={v0}
					x86e->Emit(op_pshufd ,XMM1,XMM3,0x55);          //xmm1={v1}
					x86e->Emit(op_pshufd ,XMM2,XMM3,0xaa);          //xmm2={v2}
					x86e->Emit(op_pshufd ,XMM3,XMM3,0xff);          //xmm3={v3}
				}
				else
				{
					x86e->Emit(op_movaps ,XMM0,op->rs1.reg_ptr());  //xmm0=vector

					x86e->Emit(op_movaps ,XMM3,XMM0);               //xmm3=vector
					x86e->Emit(op_shufps ,XMM0,XMM0,0);             //xmm0={v0}
					x86e->Emit(op_movaps ,XMM1,XMM3);               //xmm1=vector
					x86e->Emit(op_movaps ,XMM2,XMM3);               //xmm2=vector
					x86e->Emit(op_shufps ,XMM3,XMM3,0xff);          //xmm3={v3}
					x86e->Emit(op_shufps ,XMM1,XMM1,0x55);          //xmm1={v1}
					x86e->Emit(op_shufps ,XMM2,XMM2,0xaa);          //xmm2={v2}
				}

				//do the matrix mult !
				x86e->Emit(op_mulps ,XMM0,op->rs2.reg_ptr() + 0);   //v0*=vm0
				x86e->Emit(op_mulps ,XMM1,op->rs2.reg_ptr() + 4);   //v1*=vm1
				x86e->Emit(op_mulps ,XMM2,op->rs2.reg_ptr() + 8);   //v2*=vm2
				x86e->Emit(op_mulps ,XMM3,op->rs2.reg_ptr() + 12);  //v3*=vm3

				x86e->Emit(op_addps ,XMM0,XMM1);	 //sum it all up
				x86e->Emit(op_addps ,XMM2,XMM3);
				x86e->Emit(op_addps ,XMM0,XMM2);

				x86e->Emit(op_movaps ,op->rd.reg_ptr(),XMM0);
#else
				/*
					AABB CCDD

					ABCD *  0 1 2 3    0 1 4 5
							4 5 6 7    2 3 6 7
							8 9 a b    8 9 c d
							c d e f    a b e f
				*/

				x86e->Emit(op_movaps ,XMM1,op->rs1.reg_ptr()); //xmm1=vector

				x86e->Emit(op_pshufd ,XMM0,XMM1,0x05);         //xmm0={v0,v0,v1,v1}
				x86e->Emit(op_pshufd ,XMM1,XMM1,0xaf);         //xmm1={v2,v2,v3,v3}

				x86e->Emit(op_movaps,XMM2,XMM0);	               //xmm2={v0,v0,v1,v1}
				x86e->Emit(op_movaps,XMM3,XMM1);	               //xmm3={v2,v2,v3,v3}

				x86e->Emit(op_mulps ,XMM0,op->rs2.reg_ptr() + 0);    //aabb * 0145
				x86e->Emit(op_mulps ,XMM2,op->rs2.reg_ptr() + 4);    //aabb * 2367
				x86e->Emit(op_mulps ,XMM1,op->rs2.reg_ptr() + 8);    //ccdd * 89cd
				x86e->Emit(op_mulps ,XMM3,op->rs2.reg_ptr() + 12);   //ccdd * abef


				x86e->Emit(op_addps ,XMM0,XMM1);	 //sum it all up
				x86e->Emit(op_addps ,XMM2,XMM3);

				//XMM0 -> A0C8 | A1C9 | B4DC | B5DD
				verify(sse_3);
				
				x86e->Emit(op_shufps,XMM0,XMM0,0x27);	//A0C8 B4DC A1C9 B5DC
				x86e->Emit(op_shufps,XMM2,XMM2,0x27);
				
				x86e->Emit(op_haddps,XMM0,XMM2);	//haddps ={a0+a1 ,a2+a3 ,b0+b1 ,b2+b3}


				x86e->Emit(op_movaps ,op->rd.reg_ptr(),XMM0);
#endif
			}
			break;
			
		case shop_fmac:
			{
				verify(reg.IsAllocf(op->rs1));
				verify(reg.IsAllocf(op->rs2));
				verify(reg.IsAllocf(op->rs3));
				verify(reg.IsAllocf(op->rd));

				//rd=rs1+rs2*rs3
				//rd might be rs1,rs2 or rs3, so can't prestore here (iirc, rd==rs1==fr0)
				x86e->Emit(op_movss ,XMM0,reg.mapf(op->rs2));
				x86e->Emit(op_mulss ,XMM0,reg.mapf(op->rs3));
				x86e->Emit(op_addss ,XMM0,reg.mapf(op->rs1));
				x86e->Emit(op_movss ,reg.mapf(op->rd),XMM0);
			}
			break;

		case shop_fsrra:
			{
				verify(reg.IsAllocf(op->rs1));
				verify(reg.IsAllocf(op->rd));

				//rd=1/sqrt(rs1)
				static float one=1.0f;
				x86e->Emit(op_sqrtss ,XMM0,reg.mapf(op->rs1));
				x86e->Emit(op_movss ,reg.mapf(op->rd),&one);
				x86e->Emit(op_divss ,reg.mapf(op->rd),XMM0);
			}
			break;

		case shop_fseteq:
		case shop_fsetgt:
			{
				verify(reg.IsAllocf(op->rs1));
				verify(reg.IsAllocf(op->rs2));
				verify(reg.IsAllocg(op->rd));

				//x86e->Emit(op_movss,XMM0,op->rs1.reg_ptr());
				x86e->Emit(op_ucomiss,reg.mapf(op->rs1),reg.mapf(op->rs2));

				if (op->op==shop_fseteq)
				{
					//special case
					//We want to take in account the 'unordered' case on the fpu
					x86e->Emit(op_lahf);
					x86e->Emit(op_test8,AH,0x44);
					x86e->Emit(op_setnp,AL);
				}
				else
				{
					x86e->Emit(op_seta,AL);
				}

				x86e->Emit(op_movzx8to32,reg.mapg(op->rd),AL);
			}
			break;

		case shop_pref:
			{
				verify(op->rs1.is_r32i());
				verify(reg.IsAllocg(op->rs1));

				if (op->flags==0x1337)
				{
					//
					x86e->Emit(op_mov32 ,ECX,reg.mapg(op->rs1));
					x86e->Emit(op_call,x86_ptr_imm(&VERIFYME));	//call do_sqw_mmu
				}

				x86e->Emit(op_mov32 ,EDX,reg.mapg(op->rs1));
				x86e->Emit(op_mov32 ,ECX,reg.mapg(op->rs1));
				x86e->Emit(op_shr32 ,EDX,26);

				x86_Label* nosq=x86e->CreateLabel(false,8);

				x86e->Emit(op_cmp32,EDX,0x38);
				x86e->Emit(op_jne,nosq);
				{
					if (CCN_MMUCR.AT)
						x86e->Emit(op_call,x86_ptr_imm(&do_sqw_mmu));	//call do_sqw_mmu
					else
					{
						x86e->Emit(op_mov32 ,EDX,(u32)sq_both);
						x86e->Emit(op_call32,x86_ptr(&do_sqw_nommu));	//call [do_sqw_nommu]
					}
				}
				x86e->MarkLabel(nosq);
			}
			break;

		case shop_ext_s8:
		case shop_ext_s16:
			{
				verify(op->rd.is_r32i());
				verify(op->rs1.is_r32i());

				verify(reg.IsAllocg(op->rd));
				verify(reg.IsAllocg(op->rs1));
				
				x86e->Emit(op_mov32,EAX,reg.mapg(op->rs1));

				if (op->op==shop_ext_s8)
					x86e->Emit(op_movsx8to32,reg.mapg(op->rd),EAX);
				else
					x86e->Emit(op_movsx16to32,reg.mapg(op->rd),EAX);
			}
			break;

		case shop_cvt_f2i_t:
		{
			verify(op->rd.is_r32i());
			verify(op->rs1.is_r32f());
			verify(reg.IsAllocg(op->rd));
			verify(reg.IsAllocf(op->rs1));
			static f32 sse_ftrc_saturate = 2147483520.0f;           // IEEE 754: 0x4effffff
			x86e->Emit(op_movaps, XMM0, reg.mapf(op->rs1));
			x86e->Emit(op_minss, XMM0, &sse_ftrc_saturate);
			x86e->Emit(op_cvttss2si, reg.mapg(op->rd), XMM0);
		}
		break;

			//i hope that the round mode bit is set properly here :p
		case shop_cvt_i2f_n:
		case shop_cvt_i2f_z:
			verify(op->rd.is_r32f());
			verify(op->rs1.is_r32i());
			verify(reg.IsAllocf(op->rd));
			verify(reg.IsAllocg(op->rs1));

			x86e->Emit(op_cvtsi2ss,reg.mapf(op->rd),reg.mapg(op->rs1));
			//x86e->Emit(op_movss,op->rd.reg_ptr(),XMM0);
			break;

		case shop_frswap:
			{
				verify(op->rd._reg==op->rs2._reg);
				verify(op->rd2._reg==op->rs1._reg);

				verify(op->rs1.count()==16 && op->rs2.count()==16);
				verify(op->rd2.count()==16 && op->rd.count()==16);
#ifdef PROF2
				x86e->Emit(op_add32,&vrd,32);
#endif
				for (int i=0;i<4;i++)
				{
					x86e->Emit(op_movaps,XMM0,op->rs1.reg_ptr()+i*4);
					x86e->Emit(op_movaps,XMM1,op->rs2.reg_ptr()+i*4);
					x86e->Emit(op_movaps,op->rd.reg_ptr()+i*4,XMM0);
					x86e->Emit(op_movaps,op->rd2.reg_ptr()+i*4,XMM1);
				}
			}
			break;

		case shop_div32s:
		case shop_div32u:
			{
				x86e->Emit(op_mov32,EAX,reg.mapg(op->rs1));
				if (op->op==shop_div32s)
					x86e->Emit(op_cdq);
				else
					x86e->Emit(op_xor32,EDX,EDX);
				
				x86e->Emit(op->op==shop_div32s?op_idiv32:op_div32,reg.mapg(op->rs2));

				x86e->Emit(op_mov32,reg.mapg(op->rd),EAX);
				x86e->Emit(op_mov32,reg.mapg(op->rd2),EDX);
			}
			break;

		case shop_div32p2:
			{
				x86e->Emit(op_xor32,EAX,EAX);
				x86e->Emit(op_cmp32,reg.mapg(op->rs3),0);
				x86e->Emit(op_cmove32,EAX,reg.mapg(op->rs2));
				if (reg.mapg(op->rd)!=reg.mapg(op->rs1))
					x86e->Emit(op_mov32,reg.mapg(op->rd),reg.mapg(op->rs1));

				x86e->Emit(op_sub32,reg.mapg(op->rd),EAX);
			}
			break;


#endif

		default:
#if 1 || CANONICAL_TEST
			shil_chf[op->op](op);
			break;
#endif


defaulty:
			printf("OH CRAP %d\n",op->op);
			verify(false);
		}
}

#endif
