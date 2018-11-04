#include <types.h>
#include "shil.h"

#include <set>
#include <deque>

static inline bool operator < (const shil_param &lhs, const shil_param &rhs)
{
	u32 rhsv=rhs.type + rhs._reg*32;
	u32 lhsv=lhs.type + lhs._reg*32;

	return rhsv < lhsv;
}

template<typename nreg_t,typename nregf_t,bool explode_spans=true>
struct RegAlloc
{
	struct RegSpan;
	RegSpan* spans[sh4_reg_count];

	enum AccessMode
	{
		AM_NONE,
		AM_READ,
		AM_WRITE,
		AM_READWRITE
	};

	struct RegAccess
	{
		u32 pos;
		AccessMode am;
	};

	struct RegSpan
	{
		u32 start; //load before start
		u32 end;   //write after end

		u32 regstart;
		bool fpr;

		bool preload;
		bool writeback;

		nreg_t nreg;
		nregf_t nregf;

		bool aliased;

		vector<RegAccess> accesses;

		RegSpan(const shil_param& prm,int pos, AccessMode mode)
		{
			start=pos;
			end=pos;
			writeback=preload=false;
			regstart=prm._reg;
			fpr=prm.is_r32f();
			verify(prm.count()==1);

			aliased=false;

			if (mode&AM_WRITE)
				writeback=true;
			if (mode&AM_READ)
				preload=true;

			nreg=(nreg_t)-1;
			nregf=(nregf_t)-1;
			RegAccess ra={static_cast<u32>(pos),mode};
			accesses.push_back(ra);
		}

		void Flush()
		{
			//nothing required ?
		}

		void Kill()
		{
			writeback=false;
		}

		void Access(int pos,AccessMode mode)
		{
			end=pos;
			if (mode&AM_WRITE)
				writeback=true;
			RegAccess ra={static_cast<u32>(pos),mode};
			accesses.push_back(ra);
		}

		int pacc(int pos)
		{
			if (!contains(pos))
				return -1;

			for (int i=(int)accesses.size()-1;i>=0;i--)
			{
				if (accesses[i].pos<(u32)pos)
					return accesses[i].pos;
			}

			return -1;
		}

		int nacc(int pos)
		{
			if (!contains(pos))
				return -1;

			for (size_t i=0;i<accesses.size();i++)
			{
				if (accesses[i].pos>(u32)pos)
					return accesses[i].pos;
			}

			return -1;
		}

		int nacc_w(int pos)
		{
			if (!contains(pos))
				return -1;

			for (size_t i=0;i<accesses.size();i++)
			{
				if (accesses[i].pos>(u32)pos && accesses[i].am&AM_WRITE)
					return accesses[i].pos;
			}

			return -1;
		}

		void trim_access()
		{
			for (size_t i=0;i<accesses.size();i++)
			{
				if (!contains(accesses[i].pos))
					accesses.erase(accesses.begin()+i--);
			}
		}

		bool cacc(int pos)
		{
			return cacc_am(pos)!=AM_NONE;
		}

		AccessMode cacc_am(int pos)
		{
			if (!contains(pos)) return AM_NONE;

			for (size_t i=0; i<accesses.size(); i++)
			{
				if (accesses[i].pos==pos)
					return accesses[i].am;
			}

			return AM_NONE;
		}

		bool NeedsWB()
		{
			for (size_t i=0; i<accesses.size(); i++)
			{
				if (accesses[i].am&AM_WRITE)
					return true;
			}
			return false;
		}

		bool NeedsPL()
		{
			if (accesses[0].am&AM_READ)
				return true;

			return false;
		}

		bool begining(int pos)
		{
			return  pos==start;
		}

		bool ending(int pos)
		{
			return pos==end;
		}


		int contains(int pos)
		{
			return start<=(u32)pos && end>=(u32)pos;
		}
	};


	vector<RegSpan*> all_spans;
	u32 spills;

	u32 current_opid;
	u32 preload_fpu,preload_gpr;
	u32 writeback_fpu,writeback_gpr;

	bool IsAllocAny(Sh4RegType reg)
	{
		return IsAllocg(reg) || IsAllocf(reg);
	}

	bool IsAllocAny(const shil_param& prm)
	{
		if (prm.is_reg())
		{
			bool rv=IsAllocAny(prm._reg);
			if (prm.count()!=1)
			{
				for (u32 i=1;i<prm.count();i++)
					verify(IsAllocAny((Sh4RegType) (prm._reg+i))==rv);
			}
			return rv;
		}
		else
		{
			return false;
		}
	}

	bool IsAllocg(Sh4RegType reg)
	{
		for (u32 sid=0;sid<all_spans.size();sid++)
		{
			if (all_spans[sid]->regstart==(u32)reg && all_spans[sid]->contains(current_opid))
				return !all_spans[sid]->fpr;
		}

		return false;
	}

	bool IsAllocg(const shil_param& prm)
	{
		if (prm.is_reg())
		{
			verify(prm.count()==1);
			return IsAllocg(prm._reg);
		}
		else
		{
			return false;
		}
	}

	bool IsAllocf(Sh4RegType reg)
	{
		for (u32 sid=0;sid<all_spans.size();sid++)
		{
			if (all_spans[sid]->regstart==(u32)reg && all_spans[sid]->contains(current_opid))
				return all_spans[sid]->fpr;
		}

		return false;
	}

	bool IsAllocf(const shil_param& prm, u32 i)
	{
		verify(prm.count()>i);

		return IsAllocf((Sh4RegType)(prm._reg+i));
	}

	bool IsAllocf(const shil_param& prm)
	{
		if (prm.is_reg())
		{
			verify(prm.count()==1);
			return IsAllocf(prm._reg);
		}
		else
			return false;
	}

	nreg_t mapg(Sh4RegType reg)
	{
		verify(IsAllocg(reg));

		for (u32 sid=0;sid<all_spans.size();sid++)
		{
			if (all_spans[sid]->regstart==(u32)reg && all_spans[sid]->contains(current_opid))
			{
				verify(!all_spans[sid]->fpr);
				verify(all_spans[sid]->nreg!=-1);
				return all_spans[sid]->nreg;
			}
		}

		die("map must return value\n");
		return (nreg_t)-1;
	}

	nreg_t mapg(const shil_param& prm)
	{
		verify(IsAllocg(prm));

		if (prm.is_reg())
		{
			verify(prm.count()==1);
			return mapg(prm._reg);
		}
		else
		{
			die("map must return value\n");
			return (nreg_t)-1;
		}
	}

	nregf_t mapf(Sh4RegType reg)
	{
		verify(IsAllocf(reg));

		for (u32 sid=0;sid<all_spans.size();sid++)
		{
			if (all_spans[sid]->regstart==(u32)reg && all_spans[sid]->contains(current_opid))
			{
				verify(all_spans[sid]->fpr);
				verify(all_spans[sid]->nregf!=-1);
				return all_spans[sid]->nregf;
			}
		}

		die("map must return value\n");
		return (nregf_t)-1;
	}

	nregf_t mapf(const shil_param& prm)
	{
		verify(IsAllocf(prm));

		if (prm.is_reg())
		{
			verify(prm.count()==1);
			return mapf(prm._reg);
		}
		else
		{
			die("map must return value\n");
			return (nregf_t)-1;
		}
	}

	nregf_t mapfv(const shil_param& prm,u32 i)
	{
		verify(IsAllocf(prm,i));

		if (prm.is_reg())
		{
			return mapf((Sh4RegType)(prm._reg+i));
		}
		else
		{
			die("map must return value\n");
			return (nregf_t)-1;
		}
	}
	

	bool IsFlushOp(RuntimeBlockInfo* block, int opid)
	{
		verify(opid>=0 && opid<block->oplist.size());
		shil_opcode* op=&block->oplist[opid];

		return op->op == shop_sync_fpscr || op->op == shop_sync_sr || op->op == shop_ifb;
	}

	bool IsRegWallOp(RuntimeBlockInfo* block, int opid, bool is_fpr)
	{
		if (IsFlushOp(block,opid))
			return true;

		shil_opcode* op=&block->oplist[opid];

		return is_fpr && (op->rd.count()>=2 || op->rd2.count()>=2 || op->rs1.count()>=2 ||  op->rs2.count()>=2 || op->rs3.count()>=2 );
	}

	void InsertRegs(set<shil_param>& l, const shil_param& regs)
	{
		if (!explode_spans || (regs.count()==1 || regs.count()>2))
		{
			l.insert(regs);
		}
		else
		{
			verify(regs.type==FMT_V4 || regs.type==FMT_V2 || regs.type==FMT_F64);

			for (u32 i=0; i<regs.count(); i++)
			{
				shil_param p=regs;
				p.type=FMT_F32;
				p._reg=(Sh4RegType)(p._reg+i);

				l.insert(p);
			}
		}
	}

	RegSpan* FindSpan(Sh4RegType reg, u32 opid)
	{
		for (u32 sid=0;sid<all_spans.size();sid++)
		{
			if (all_spans[sid]->regstart==(u32)reg && all_spans[sid]->contains(opid))
			{
				return all_spans[sid];
			}
		}
		die("Failed to find span");
		return NULL;
	}

	void flush_span(u32 sid)
	{
		if (spans[sid]) 
		{
			spans[sid]->Flush();
			spans[sid]=0;
		}
	}
	void DoAlloc(RuntimeBlockInfo* block,const nreg_t* nregs_avail,const nregf_t* nregsf_avail)
	{
		Cleanup();
		shil_opcode* op;
		for (size_t opid=0;opid<block->oplist.size();opid++)
		{
			op=&block->oplist[opid];

			/*
			if (op->op!=shop_readm && op->op!=shop_writem && ( op->rd.is_vector() ||op->rs1.is_vector()))
			{
			//	__asm int 3;
			}*/

			//if (op->op != shop_readm && op->op != shop_writem && op->op != shop_jcond && op->op != shop_jdyn && op->op != shop_mov32 && op->op != shop_mov64 && (op->op != shop_add || block->addr<=0x8c0DA0BA))
			if (IsFlushOp(block,opid))
			{
				bool fp=false,gpr_b=false,all=false;

					#define GetN(str) ((str>>8) & 0xf)
#define GetM(str) ((str>>4) & 0xf)
#define Mask_n_m 0xF00F
#define Mask_n_m_imm4 0xF000
#define Mask_n 0xF0FF
#define Mask_none 0xFFFF
#define Mask_imm8 0xFF00
#define Mask_imm12 0xF000
#define Mask_n_imm8 0xF000
#define Mask_n_ml3bit 0xF08F
#define Mask_nh3bit 0xF1FF
#define Mask_nh2bit 0xF3FF

				if (op->op==shop_ifb)
				{
					flush_span(reg_r0);
					flush_span(reg_sr_T);
					flush_span(reg_sr_status);
					flush_span(reg_fpscr);

					for (int i=reg_gbr;i<=reg_fpul;i++)
						flush_span(i);

					for (int i=reg_gbr;i<=reg_fpul;i++)
						flush_span(i);


					switch(OpDesc[op->rs3._imm]->mask)
					{
					case Mask_imm8:
						break;



					case Mask_n_m:
					case Mask_n_m_imm4:
					case Mask_n_ml3bit:
						flush_span(GetN(op->rs3._imm));
						flush_span(GetM(op->rs3._imm));
						break;

					default:
						all=true;
						break;
					}

					if (op->rs3._imm>=0xF000)
						fp=true;

				}
				else if(op->op==shop_sync_sr)
				{
					gpr_b=true;
				}
				else if (op->op==shop_sync_fpscr)
				{
					fp=true;
				}

				if (all)
				{
					//flush
					for (int sid=0;sid<sh4_reg_count;sid++)
					{
						if (sid<reg_fr_0 || sid>reg_xf_15)
							flush_span(sid);
					}
				}

				if (fp)
				{
					//flush
					flush_span(reg_fpscr);
					flush_span(reg_old_fpscr);

					for (int sid=0;sid<16;sid++)
					{
						flush_span(reg_fr_0+sid);
						flush_span(reg_xf_0+sid);
					}
				}

				if (gpr_b)
				{
					//flush
					flush_span(reg_sr_status);
					flush_span(reg_old_sr_status);

					for (int sid=0;sid<8;sid++)
					{
						flush_span(reg_r0+sid);
						flush_span(reg_r0_Bank+sid);
					}
				}

			}
			else
			{
				set<shil_param> reg_wt;
				set<shil_param> reg_rd;

				//insert regs into sets ..
				InsertRegs(reg_wt,op->rd);
				
				InsertRegs(reg_wt,op->rd2);

				InsertRegs(reg_rd,op->rs1);
				
				InsertRegs(reg_rd,op->rs2);

				InsertRegs(reg_rd,op->rs3);

				set<shil_param>::iterator iter=reg_wt.begin();
				while( iter != reg_wt.end() ) 
				{
					if (reg_rd.count(*iter))
					{
						reg_rd.erase(*iter);
						{
							if ((*iter).is_reg())
							{
								//r~w
								if ((*iter).is_r32())
								{
									if (spans[(*iter)._reg]==0)
									{
										spans[(*iter)._reg] = new RegSpan((*iter),opid,AM_READWRITE);
										all_spans.push_back(spans[(*iter)._reg]);
									}
									else
									{
										spans[(*iter)._reg]->Access(opid,AM_READWRITE);
									}
								}
								else
								{
									for (u32 i=0; i<(*iter).count(); i++)
									{
										if (spans[(*iter)._reg+i]!=0)
											spans[(*iter)._reg+i]->Flush();

										spans[(*iter)._reg+i]=0;
									}
								}
							}
						}
					}
					else
					{
						if ((*iter).is_reg())
						{
							for (u32 i=0; i<(*iter).count(); i++)
							{
								if (spans[(*iter)._reg+i]!=0)
								{
									//hack//
									//this is a bug on the current reg alloc code, affects fipr.
									//generally, vector registers aren't treated correctly
									//as groups of phy registers. I really need a better model
									//to accommodate for that on the reg alloc side of things ..
									if ((*iter).count()==1 && iter->_reg==op->rs1._reg+3)
										spans[(*iter)._reg+i]->Flush();
									else
										spans[(*iter)._reg+i]->Kill();
								}
								spans[(*iter)._reg+i]=0;
							}

							//w
							if ((*iter).is_r32())
							{
								if (spans[(*iter)._reg]!=0)
									spans[(*iter)._reg]->Kill();

								spans[(*iter)._reg]= new RegSpan((*iter),opid,AM_WRITE);
								all_spans.push_back(spans[(*iter)._reg]);
							}
						}
					}
					++iter;
				}

				iter=reg_rd.begin();
				while( iter != reg_rd.end() ) 
				{
					//r
					if ((*iter).is_reg())
					{
						if ((*iter).is_r32())
						{
							if (spans[(*iter)._reg]==0)
							{
								spans[(*iter)._reg] = new RegSpan((*iter),opid,AM_READ);
								all_spans.push_back(spans[(*iter)._reg]);
							}
							else
							{
								spans[(*iter)._reg]->Access(opid,AM_READ);
							}
						}
						else
						{
							for (u32 i=0; i<(*iter).count(); i++)
							{
								if (spans[(*iter)._reg+i]!=0)
									spans[(*iter)._reg+i]->Flush();

								spans[(*iter)._reg+i]=0;
							}
						}
					}
					++iter;
				}
			
				/*
				for (int sid=0;sid<sh4_reg_count;sid++)
				{
					if (spans[sid]) 
					{
						spans[sid]->Flush();
						spans[sid]=0;
					}
				}
				*/
			}

		}

		// create register lists
		deque<nreg_t> regs;
		deque<nregf_t> regsf;

		const nreg_t* nregs=nregs_avail;

		while (*nregs!=-1)
			regs.push_back(*nregs++);

		u32 reg_cc_max_g=regs.size();

		const nregf_t* nregsf=nregsf_avail;

		while (*nregsf!=-1)
			regsf.push_back(*nregsf++);

		u32 reg_cc_max_f=regsf.size();

		
		//Trim span count to max reg count
		for (size_t opid=0;opid<block->oplist.size();opid++)
		{
			u32 cc_g=0;
			u32 cc_f=0;

			for (u32 sid=0;sid<all_spans.size();sid++)
			{
				if (all_spans[sid]->contains(opid))
				{
					if (all_spans[sid]->fpr)
						cc_f++;
					else
						cc_g++;
				}
			}

			SplitSpans(cc_g,reg_cc_max_g,false,opid);

			SplitSpans(cc_f,reg_cc_max_f,true,opid);

			if (false)
			{
				printf("After reduction ..\n");
				for (u32 sid=0;sid<all_spans.size();sid++)
				{
					RegSpan* spn=all_spans[sid];

					if (spn->contains(opid))
						printf("\t[%c]span: %d (r%d), [%d:%d],n: %d, p: %d\n",spn->cacc(opid)?'x':' ',sid,all_spans[sid]->regstart,all_spans[sid]->start,all_spans[sid]->end,all_spans[sid]->nacc(opid),all_spans[sid]->pacc(opid));
				}
			}
		}

		//Allocate the registers to the spans !
		for (size_t opid=0;opid<block->oplist.size();opid++)
		{
			bool alias_mov=false;

			if (block->oplist[opid].op==shop_mov32 && 
				( 
				(block->oplist[opid].rd.is_r32i() && block->oplist[opid].rs1.is_r32i() ) || 
				(block->oplist[opid].rd.is_r32f() && block->oplist[opid].rs1.is_r32f() )
				))
			{
				//FindSpan(block->oplist[opid].rd._reg);
				RegSpan* x=FindSpan(block->oplist[opid].rs1._reg,opid);
				if (0 && x->nacc_w(opid)==-1 && (x->nreg!=-1 || x->nregf!=-1) && !x->aliased)
				{
					RegSpan* d=FindSpan(block->oplist[opid].rd._reg,opid);
					int nwa=d->nacc_w(opid);

					if (nwa==-1 || nwa>=x->end)
					{

						verify(d->fpr==x->fpr);
						d->nreg=x->nreg;
						d->nregf=x->nregf;
						//x->aliased=true;

						verify(d->begining(opid) && !d->preload);
						//verify(d->end>=x->end);

						if (d->end>=x->end)
							x->aliased=true;
						else
							d->aliased=true;

						//printf("[%08X] rALIA %d from %d\n",spn,spn->regstart,spn->nreg);
						alias_mov=true;
					}
				}
			}

			if (!alias_mov)
			{
				for (u32 sid=0;sid<all_spans.size();sid++)
				{
					RegSpan* spn=all_spans[sid];

					if (spn->begining(opid))
					{
						if (spn->fpr)
						{
							verify(regsf.size()>0);
							spn->nregf=regsf.back();
							regsf.pop_back();
						}
						else
						{
							verify(regs.size()>0);
							spn->nreg=regs.back();
							regs.pop_back();

							//printf("rALOC %d from %d\n",spn->regstart,spn->nreg);
						}
					}
				}
			}
			for (u32 sid=0;sid<all_spans.size();sid++)
			{
				RegSpan* spn=all_spans[sid];

				if ( spn->ending(opid) && !spn->aliased)
				{
					if (spn->fpr)
					{
						verify(regsf.size()<reg_cc_max_f);
						regsf.push_front(spn->nregf);
					}
					else
					{
						verify(regs.size()<reg_cc_max_g);
						regs.push_front(spn->nreg);
						//printf("rFREE %d from %d\n",spn->regstart,spn->nreg);
					}
				}
			}
		}

		verify(regs.size()==reg_cc_max_g);
		verify(regsf.size()==reg_cc_max_f);

	//Pipeline optimisations

#ifdef REGALLOC_PIPELINE
	//move spans earlier for preloading !
#if 1
		for (u32 sid=0;sid<all_spans.size();sid++)
		{
			RegSpan* spn=all_spans[sid];
			
			if (spn->start==0) continue; //can't move anyway ..

			//try to move beginnings backwards
			u32 opid;
			for (opid=spn->start;opid-->0;)
			{
				if (!SpanRegIntr(opid,spn->regstart) &&  ( spn->fpr ? !SpanNRegfIntr(opid,spn->nregf) : !SpanNRegIntr(opid,spn->nreg)) && !IsRegWallOp(block,opid,spn->fpr))
					continue;
				else
					break;
			}
			opid++;

			//
			//this can cause slowdowns on aggregation of load/stores
			//we need some slack mechanism to distribute it !
			//<< this will for now blindly avoid >2preload/op
			//it still slows it down so disabled

			if (spn->start>opid)
			{
				int opid_found=-1;
				int opid_plc=60;

				int slack=spn->start-opid;

				while (spn->start>opid)
				{
					if (SpanPLD(opid)<opid_plc)
					{
						opid_found=opid;
						opid_plc=SpanPLD(opid);
					}
					if (opid_found!=-1 && (spn->start-opid)<=1 && opid_plc<2)
						break;
					
					opid++;
				}

				bool do_move= false;
				
				if (opid_found!=-1)
				{
					do_move=true;
					do_move &= opid_plc<3;
				}

				if ( do_move)
				{
					printf("Span PLD is movable by %d, moved by %d w/ %d!!\n",slack,spn->start-opid_found,opid_plc);
					spn->start=opid_found;
				}
				else
				{
					printf("Span PLD is movable by %d but  %d -> not moved :(\n",slack,opid_plc);
				}
			}
		}
#endif

	//move spans later for post-saving !
#if 1
		u32 blk_last=block->oplist.size()-1;

		for (u32 sid=0;sid<all_spans.size();sid++)
		{
			RegSpan* spn=all_spans[sid];
			
			if (spn->end==blk_last) continue; //can't move anyway ..

			//try to move beginnings backwards
			u32 opid;
			for (opid=spn->end+1;opid<=blk_last;opid++)
			{
				if (!SpanRegIntr(opid,spn->regstart) &&  ( spn->fpr ? !SpanNRegfIntr(opid,spn->nregf) : !SpanNRegIntr(opid,spn->nreg)) && !IsRegWallOp(block,opid,spn->fpr))
					continue;
				else
					break;
			}
			opid--;

			//
			//this can cause slowdowns on aggregation of load/stores
			//we need some slack mechanism to distribute it !
			//<< this will for now blindly avoid >1preload/op
			//it still slows it down so disabled

			if (spn->end<opid)
			{
				int opid_found=-1;
				int opid_plc=60;

				int slack=opid-spn->end;

				while (spn->end<opid)
				{
					if (SpanWB(opid)<opid_plc)
					{
						opid_found=opid;
						opid_plc=SpanWB(opid);
					}

					if (opid_found!=-1 && (opid-spn->end)<=1 && opid_plc<2)
						break;
					
					opid--;
				}

				bool do_move= false;

				if (opid_found!=-1)
				{
					do_move=true;
					do_move &= opid_plc<3;
				}

				if ( do_move)
				{
					printf("Span WB is movable by %d, moved by %d w/ %d!!\n",slack,opid_found-spn->end,opid_plc);
					spn->end=opid_found;
				}
				else
				{
					printf("Span WB is movable by %d but  %d -> not moved :(\n",slack,opid_plc);
				}
			}
		}
#endif

#endif
		//printf("%d spills\n",spills);
	}


	void SplitSpans(u32 cc,u32 reg_cc_max ,bool fpr,u32 opid)
	{
		bool was_large=false;	//this control prints

		while (cc>reg_cc_max)
		{
			if (was_large)
				printf("Opcode: %d, %d active spans\n",opid,cc);

			RegSpan* last_pacc=0;
			RegSpan* last_nacc=0;

			for (u32 sid=0;sid<all_spans.size();sid++)
			{
				RegSpan* spn=all_spans[sid];

				if (spn->contains(opid) && fpr==spn->fpr)
				{
					if (!spn->cacc(opid))
					{
						if (!last_nacc || spn->nacc(opid)>last_nacc->nacc(opid))
							last_nacc=spn;

						if (!last_pacc || spn->pacc(opid)<last_pacc->pacc(opid))
							last_pacc=spn;
					}
					if (was_large)
						printf("\t[%c]span: %d (r%d), [%d:%d],n: %d, p: %d\n",spn->cacc(opid)?'x':' ',sid,all_spans[sid]->regstart,all_spans[sid]->start,all_spans[sid]->end,all_spans[sid]->nacc(opid),all_spans[sid]->pacc(opid));
				}
			}

			//printf("Last pacc: %d, vlen %d | reg r%d\n",last_pacc->nacc(opid)-opid,last_pacc->nacc(opid)-last_pacc->pacc(opid),last_pacc->regstart);
			//printf("Last nacc: %d, vlen %d | reg r%d\n",last_nacc->nacc(opid)-opid,last_nacc->nacc(opid)-last_nacc->pacc(opid),last_nacc->regstart);

			RegSpan* spn= new RegSpan(*last_nacc);
			spn->start=last_nacc->nacc(opid);
			last_nacc->end=last_nacc->pacc(opid);

			//trim the access arrays as required ..
			spn->trim_access();
			last_nacc->trim_access();

			spn->preload=spn->NeedsPL();
			last_nacc->writeback=last_nacc->NeedsWB();

			//add it to the span list !
			all_spans.push_back(spn);
			spills++;
			cc--;
		}
	}

	int SpanRegIntr(int opid,u32 reg)
	{
		verify(reg!=-1);
		int cc=0;
		for (u32 sid=0;sid<all_spans.size();sid++)
		{
			if (all_spans[sid]->regstart==reg && all_spans[sid]->contains(opid))
				cc++;
		}
		return cc;
	}

	int SpanNRegIntr(int opid,nreg_t nreg)
	{
		verify(nreg!=-1);
		int cc=0;
		for (u32 sid=0;sid<all_spans.size();sid++)
		{
			if (all_spans[sid]->nreg==nreg && all_spans[sid]->contains(opid))
				cc++;
		}
		return cc;
	}

	int SpanNRegfIntr(int opid,nregf_t nregf)
	{
		verify(nregf!=-1);
		int cc=0;
		for (u32 sid=0;sid<all_spans.size();sid++)
		{
			if (all_spans[sid]->nregf==nregf && all_spans[sid]->contains(opid))
				cc++;
		}
		return cc;
	}

	int SpanPLD(int opid)
	{
		int rv=0;

		for (u32 sid=0;sid<all_spans.size();sid++)
		{
			RegSpan* spn=all_spans[sid];

			if (spn->preload && spn->begining(opid))
				rv++;
		}

		return rv;
	}

	int SpanWB(int opid)
	{
		int rv=0;

		for (u32 sid=0;sid<all_spans.size();sid++)
		{
			RegSpan* spn=all_spans[sid];

			if (spn->writeback && spn->ending(opid))
				rv++;
		}

		return rv;
	}

	void OpBegin(shil_opcode* op,int opid)
	{
		current_opid=opid;

		for (u32 sid=0;sid<all_spans.size();sid++)
		{
			RegSpan* spn=all_spans[sid];

			if (spn->begining(current_opid) && spn->preload)
			{
				//printf("Op %d: Preloading r%d to %d\n",current_opid,spn->regstart,spn->nreg);
				if (spn->fpr)
				{
					preload_fpu++;
					Preload_FPU(spn->regstart,spn->nregf);
				}
				else
				{
					preload_gpr++;
					Preload(spn->regstart,spn->nreg);
				}
			}
		}
	}

	void OpEnd(shil_opcode* op)
	{
		for (u32 sid=0;sid<all_spans.size();sid++)
		{
			RegSpan* spn=all_spans[sid];

			if (spn->ending(current_opid) && spn->writeback)
			{
				//printf("Op %d: Writing back r%d to %d\n",current_opid,spn->regstart,spn->nreg);
				if (spn->fpr)
				{
					writeback_fpu++;
					Writeback_FPU(spn->regstart,spn->nregf);
				}
				else
				{
					writeback_gpr++;
					Writeback(spn->regstart,spn->nreg);
				}
			}
		}
	}

	void Cleanup()
	{
		writeback_gpr=writeback_fpu=0;
		preload_gpr=preload_fpu=0;

		for (int sid=0;sid<sh4_reg_count;sid++)
		{
			if (spans[sid]) 
				spans[sid]=0;
		}

		for (size_t sid=0;sid<all_spans.size();sid++)
			delete all_spans[sid];

		all_spans.clear();
	}

	virtual nregf_t FpuMap(u32 reg) { return (nregf_t)-1; }

	virtual void Preload(u32 reg,nreg_t nreg)=0;
	virtual void Writeback(u32 reg,nreg_t nreg)=0;

	virtual void Preload_FPU(u32 reg,nregf_t nreg)=0;
	virtual void Writeback_FPU(u32 reg,nregf_t nreg)=0;
};