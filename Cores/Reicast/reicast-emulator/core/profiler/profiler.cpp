#include "profiler.h"

profiler_cfg prof;

void prof_init()
{
	memset(&prof,0,sizeof(prof));
	prof.enable=false;
}

struct regacc
{
	Sh4RegType reg;

	u32 sum;
	u32 r;
	u32 w;
	u32 rw;

	void print()
	{
		printf("%02d: %d || %d %d %d\n",reg,sum,r,w,rw);
	}

	bool operator< (const regacc& rhs) const
	{
		return sum>rhs.sum;
	}
};

#include "hw/sh4/sh4_opcode_list.h"

int stuffcmp(const void* p1,const void* p2)
{
	sh4_opcodelistentry* a=(sh4_opcodelistentry*)p1;
	sh4_opcodelistentry* b=(sh4_opcodelistentry*)p2;

	return b->fallbacks-a->fallbacks;
}

extern u32 ret_hit,ret_all,ret_stc;

extern u32 bm_gc_luc,bm_gcf_luc,cvld;
extern u32 rdmt[6];

u32 SQW,DMAW;

u32 TA_VTXC,TA_SPRC,TA_EOSC,TA_PPC,TA_SPC,TA_EOLC,TA_V64HC;

u32 TA_VTX_O;
u32 PVR_VTXC;
u32 stati;

u32 memops_t,memops_l;

u32 rmls,rmlu;
u32 srmls,srmlu,srmlc;
u32 wmls,wmlu;
u32 flsh;
u32 vrd;
u32 vrml_431;

extern u32 nfb,ffb,bfb,mfb;
u32 ralst[4];

extern u32 samples_gen;

void print_blocks();

#if FEAT_SHREC != DYNAREC_NONE
//called every emulated second
void prof_periodical()
{
#if defined(HAS_PROFILE)
#if 0
	printf("SQW %d,DMAW %d\n",SQW,DMAW);
	DMAW=SQW=0;
#endif

#if FEAT_SHREC != DYNAREC_NONE
	print_blocks();
#endif

	return;

	printf("TA_VTXC %d,TA_SPRC %d,TA_EOSC %d,TA_PPC %d,TA_SPC %d,TA_EOLC %d,TA_V64HC %d\n", TA_VTXC,TA_SPRC,TA_EOSC,TA_PPC,TA_SPC,TA_EOLC,TA_V64HC);
	TA_VTXC=TA_SPRC=TA_EOSC=TA_PPC=TA_SPC=TA_EOLC=TA_V64HC=0;



	//for (u32 i=0;i<all_blocks
	return;

	#if HOST_OS!=OS_WINDOWS
		return;
	#endif

	printf("Samples Gen: %.2f %.2f\n",samples_gen/1000.0,samples_gen/44100.0);
	samples_gen=0;
	return;

	printf("PLD G: %.2f, WB G %.2f, PLD F: %.2f, WB F: %.2f\n"	,ralst[0]/1000000.0,ralst[2]/1000000.0
																,ralst[1]/1000000.0,ralst[3]/1000000.0);
	memset(ralst,0,sizeof(ralst));
	return;

	printf("READMV 431: %.2fm\n",vrml_431/1000.0/1000.0);
	vrml_431=0;
	if (nfb+ffb+bfb+mfb)
	{
		printf("n:%d, f:%d, m:%d, b:%d || %.2f:1\n",nfb,ffb,mfb,bfb,(float)nfb/(mfb+ffb+bfb));
		mfb=bfb=nfb=ffb=0;
	}
	return;

#if HOST_CPU==CPU_X86
	double ret_fail=ret_all-ret_hit-ret_stc;
	if (ret_fail==0) ret_fail=0.001;

	printf("Ret cache: %.2fM rets, %.2f:1 HRD, %.2f:1 HRS, %.2f:1 DSR, %.0f fails, %.2f:1 HRAll\n",
		ret_all/1000.0/1000.0,ret_hit/ret_fail,ret_stc/ret_fail,ret_hit/(double)ret_stc,ret_fail,(ret_stc+ret_hit)/ret_fail);
	ret_stc=ret_hit=ret_all=0;
#endif

#if HOST_CPU==CPU_X86
	if (bm_gcf_luc==0)
		bm_gcf_luc=1;
	//printf("BM: GC %d/%d %.2f:1\n",bm_gcf_luc,bm_gc_luc,bm_gc_luc/(float)bm_gcf_luc);
	bm_gcf_luc=bm_gc_luc=0;

	printf("FLUSHES : %.2f || %.2f -- %.2f:1\n",32*(flsh-rmlu-wmlu)/1000000.0,(vrd)/1000000.0,vrd/(32.0*(flsh-rmlu-wmlu)));
	vrd=flsh=0;

	printf("linked memops,  %.2f:1 %.2fM lookups saved, %.2f total\n",memops_t/(double)(memops_t-memops_l), memops_l/1000000.0,memops_t/1000000.0);
	memops_l=memops_t=0;

	printf("fast Sreadm, %.2f c, %.2f:1 %.2fM fp, %.2f total\n",srmlc/1000000.0,srmlu/(double)srmls, srmlu/1000000.0,(srmlu+srmls)/1000000.0);
	srmlc=srmls=srmlu=0;
	printf("fast readm, %.2f:1 %.2fM fp, %.2f total\n",rmlu/(double)rmls, rmlu/1000000.0,(rmlu+rmls)/1000000.0);
	rmls=rmlu=0;
	printf("fast writem, %.2f:1 %.2fM fp, %.2f total\n",wmlu/(double)wmls, wmlu/1000000.0,(wmlu+wmls)/1000000.0);
	wmls=wmlu=0;
#endif

#if HOST_CPU==CPU_X86 && 0
	printf("Static: %.2f\n",stati/1000.0);
	printf("cvld: %.2f\n",cvld/1000.0/1000.0);
	printf("rdmt: %.2f %.2f %.2f %.2f\n",rdmt[0]/1000000.0,rdmt[1]/1000000.0,rdmt[2]/1000000.0,rdmt[3]/1000000.0);
	printf("rdmti: %.2f %.2f \n",rdmt[4]/1000000.0,rdmt[5]/1000000.0);

	rdmt[0]=rdmt[1]=rdmt[2]=rdmt[3]=rdmt[4]=rdmt[5]=0;
	cvld=0;
	stati=0;

	printf("TA %.2f %.2f || %.2f\n",TA_VTXC/1000.0,TA_SPRC/1000.0,TA_VTX_O/1000.0);
	printf("PVR %.2f\n",PVR_VTXC/1000.0);
	
	TA_VTXC=TA_SPRC=TA_VTX_O=PVR_VTXC=0;

#endif
	for(int i=0;i<shop_max;i++)
	{
		double v=prof.counters.shil.executed[i]/1000.0/1000.0;
		prof.counters.shil.executed[i]=0;
		if (v>0.05)
			printf("%s: %.2fM\n",shil_opcode_name(i),v);
	}

	
	if (prof.counters.shil.readm_reg!=0)
	{
		printf("***PROFILE REPORT***\n");
		prof.counters.print();
	}

	printf("opcode fallbacks:\n");
	vector<sh4_opcodelistentry> stuff;
	for (u32 i=0;opcodes[i].oph;i++)
	{
		if (opcodes[i].fallbacks)
			stuff.push_back(opcodes[i]);
	}

	if (stuff.size())
	{
		qsort(&stuff[0],stuff.size(),sizeof(stuff[0]),stuffcmp);
		for (u32 i=0;i<10 && i<stuff.size();i++)
		{
			printf("%05I64u :%04X %s\n",stuff[i].fallbacks,stuff[i].rez,stuff[i].diss);
		}
	}

	for (u32 i=0;opcodes[i].oph;i++)
	{
		opcodes[i].fallbacks=0;
	}

	printf("********************\n");
	memset(&prof.counters,0,sizeof(prof.counters));
#endif
}
#else
void prof_periodical() { }
#endif
/*

	debprof: a remote debugger/profiler


	Text based i/o

	var = x
	varN = { .. }


	Commands:
	name(par1=x,par2=y)

	
*/
