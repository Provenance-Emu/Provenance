/*
	sh4 base core
	most of it is (very) old
	could use many cleanups, lets hope someone does them
*/

//All non fpu opcodes :)
#include "types.h"


#include "hw/pvr/pvr_mem.h"
#include "../sh4_interpreter.h"
#include "hw/sh4/sh4_mem.h"
#include "hw/sh4/sh4_mmr.h"
#include "../sh4_core.h"
#include "../modules/ccn.h"
#include "../sh4_interrupts.h"
#include "../modules/tmu.h"
#include "hw/gdrom/gdrom_if.h"

#include "hw/sh4/sh4_opcode.h"

void dofoo(sh4_opcode op)
{
	r[op.n()]=gbr;
}

#define GetN(str) ((str>>8) & 0xf)
#define GetM(str) ((str>>4) & 0xf)
#define GetImm4(str) ((str>>0) & 0xf)
#define GetImm8(str) ((str>>0) & 0xff)
#define GetSImm8(str) ((s8)((str>>0) & 0xff))
#define GetImm12(str) ((str>>0) & 0xfff)
#define GetSImm12(str) (((s16)((GetImm12(str))<<4))>>4)

#define iNimp cpu_iNimp
#define iWarn cpu_iWarn

//Read Mem macros

#define ReadMemU32(to,addr) to=ReadMem32(addr)
#define ReadMemS32(to,addr) to=(s32)ReadMem32(addr)
#define ReadMemS16(to,addr) to=(u32)(s32)(s16)ReadMem16(addr)
#define ReadMemS8(to,addr)  to=(u32)(s32)(s8)ReadMem8(addr)

//Base,offset format
#define ReadMemBOU32(to,addr,offset)    ReadMemU32(to,addr+offset)
#define ReadMemBOS16(to,addr,offset)    ReadMemS16(to,addr+offset)
#define ReadMemBOS8(to,addr,offset)     ReadMemS8(to,addr+offset)

//Write Mem Macros
#define WriteMemU32(addr,data)          WriteMem32(addr,(u32)data)
#define WriteMemU16(addr,data)          WriteMem16(addr,(u16)data)
#define WriteMemU8(addr,data)           WriteMem8(addr,(u8)data)

//Base,offset format
#define WriteMemBOU32(addr,offset,data) WriteMemU32(addr+offset,data)
#define WriteMemBOU16(addr,offset,data) WriteMemU16(addr+offset,data)
#define WriteMemBOU8(addr,offset,data)  WriteMemU8(addr+offset,data)

// 0xxx
void cpu_iNimp(u32 op, const char* info)
{
	printf("\n\nUnimplemented opcode: %08X next_pc: %08X pr: %08X msg: %s\n", op, next_pc, pr, info);
	//next_pc = pr; //debug hackfix: try to recover by returning from call
	die("iNimp reached\n");
	//sh4_cpu.Stop();
}

void cpu_iWarn(u32 op, const char* info)
{
	printf("Check opcode : %X : ", op);
	printf("%s", info);
	printf(" @ %X\n", curr_pc);
}

//this file contains ALL register to register full moves
//

//stc GBR,<REG_N>
sh4op(i0000_nnnn_0001_0010)
{
	//iNimp("stc GBR,<REG_N>");
	u32 n = GetN(op);
	r[n] = gbr;
}


//stc VBR,<REG_N>
sh4op(i0000_nnnn_0010_0010)
{
	//iNimp("stc VBR,<REG_N>  ");
	u32 n = GetN(op);
	r[n] = vbr;
}


//stc SSR,<REG_N>
sh4op(i0000_nnnn_0011_0010)
{
	//iNimp("stc SSR,<REG_N>");
	u32 n = GetN(op);
	r[n] = ssr;
}

//stc SGR,<REG_N>
sh4op(i0000_nnnn_0011_1010)
{
	//iNimp("stc SGR,<REG_N>");
	u32 n = GetN(op);
	r[n] = sgr;
}

//stc SPC,<REG_N>
sh4op(i0000_nnnn_0100_0010)
{
	//iNimp("stc SPC,<REG_N> ");
	u32 n = GetN(op);
	r[n] = spc;
}


//stc RM_BANK,<REG_N>
sh4op(i0000_nnnn_1mmm_0010)
{
	//iNimp(op,"stc R0_BANK,<REG_N>\n");
	u32 n = GetN(op);
	u32 m = GetM(op) & 0x7;
	r[n] = r_bank[m];
}

//sts FPUL,<REG_N>
sh4op(i0000_nnnn_0101_1010)
{
	u32 n = GetN(op);
	r[n] = fpul;
}

//stc DBR,<REG_N>
sh4op(i0000_nnnn_1111_1010)
{
	u32 n = GetN(op);
	r[n] = dbr;
}


//sts MACH,<REG_N>
sh4op(i0000_nnnn_0000_1010)
{
	u32 n = GetN(op);
	r[n] = mac.h;
}


//sts MACL,<REG_N>
sh4op(i0000_nnnn_0001_1010)
{
	u32 n = GetN(op);
	r[n]=mac.l;
}


//sts PR,<REG_N>
sh4op(i0000_nnnn_0010_1010)
{
	//iNimp("sts PR,<REG_N>");
	u32 n = GetN(op);
	r[n] = pr;
}


 //mov.b @(R0,<REG_M>),<REG_N>
sh4op(i0000_nnnn_mmmm_1100)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	ReadMemBOS8(r[n],r[0],r[m]);
	//r[n]= (u32)(s8)ReadMem8(r[0]+r[m]);
}


//mov.w @(R0,<REG_M>),<REG_N>
sh4op(i0000_nnnn_mmmm_1101)
{//ToDo : Check This [26/4/05]
	//iNimp("mov.w @(R0,<REG_M>),<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);
	ReadMemBOS16(r[n],r[0],r[m]);
	//r[n] = (u32)(s16)ReadMem16(r[0] + r[m]);
}


//mov.l @(R0,<REG_M>),<REG_N>
sh4op(i0000_nnnn_mmmm_1110)
{
	//iNimp("mov.l @(R0,<REG_M>),<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);

	ReadMemBOU32(r[n],r[0],r[m]);
}

 //mov.b <REG_M>,@(R0,<REG_N>)
sh4op(i0000_nnnn_mmmm_0100)
{
	//iNimp("mov.b <REG_M>,@(R0,<REG_N>)");
	u32 n = GetN(op);
	u32 m = GetM(op);

	WriteMemBOU8(r[0],r[n], r[m]);
	//WriteMem8(r[0] + r[n], (u8)r[m]);
}


//mov.w <REG_M>,@(R0,<REG_N>)
sh4op(i0000_nnnn_mmmm_0101)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	WriteMemBOU16(r[0] , r[n], r[m]);
}


//mov.l <REG_M>,@(R0,<REG_N>)
sh4op(i0000_nnnn_mmmm_0110)
{
	//iNimp("mov.l <REG_M>,@(R0,<REG_N>)");
	u32 n = GetN(op);
	u32 m = GetM(op);
	WriteMemBOU32(r[0], r[n], r[m]);
}



//
// 1xxx

//mov.l <REG_M>,@(<disp>,<REG_N>)
sh4op(i0001_nnnn_mmmm_iiii)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	u32 disp = GetImm4(op);
	WriteMemBOU32(r[n] , (disp <<2), r[m]);
}

//
//	2xxx

//mov.b <REG_M>,@<REG_N>
sh4op(i0010_nnnn_mmmm_0000)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	WriteMemU8(r[n],r[m] );
}

// mov.w <REG_M>,@<REG_N>
sh4op(i0010_nnnn_mmmm_0001)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	WriteMemU16(r[n],r[m]);
}

// mov.l <REG_M>,@<REG_N>
sh4op(i0010_nnnn_mmmm_0010)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	WriteMemU32(r[n],r[m]);
}

// mov.b <REG_M>,@-<REG_N>
sh4op(i0010_nnnn_mmmm_0100)
{
	//iNimp("mov.b <REG_M>,@-<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);
	
	u32 addr = r[n] - 1;
	WriteMemBOU8(r[n], (u32)-1, r[m]);
	r[n] = addr;
}

//mov.w <REG_M>,@-<REG_N>
sh4op(i0010_nnnn_mmmm_0101)
{
	//iNimp("mov.w <REG_M>,@-<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);

	u32 addr = r[n] - 2;
	WriteMemU16(addr, r[m]);
	r[n] = addr;
}

//mov.l <REG_M>,@-<REG_N>
sh4op(i0010_nnnn_mmmm_0110)
{
	u32 n = GetN(op);
	u32 m = GetM(op);

	u32 addr = r[n] - 4;
	WriteMemU32(addr, r[m]);
	r[n] = addr;
}

 //
// 4xxx
//sts.l FPUL,@-<REG_N>
sh4op(i0100_nnnn_0101_0010)
{
	//iNimp("sts.l FPUL,@-<REG_N>");
	u32 n = GetN(op);

	u32 addr = r[n] - 4;
	WriteMemU32(addr, fpul);
	r[n] = addr;
}

//sts.l MACH,@-<REG_N>
sh4op(i0100_nnnn_0000_0010)
{
	u32 n = GetN(op);

	u32 addr = r[n] - 4;
	WriteMemU32(addr, mac.h);
	r[n] = addr;
}


//sts.l MACL,@-<REG_N>
sh4op(i0100_nnnn_0001_0010)
{
	u32 n = GetN(op);
	
	u32 addr = r[n] - 4;
	WriteMemU32(addr, mac.l);
	r[n] = addr;
}


//sts.l PR,@-<REG_N>
sh4op(i0100_nnnn_0010_0010)
{
	u32 n = GetN(op);

	u32 addr = r[n] - 4;
	WriteMemU32(addr,pr);
	r[n] = addr;
}

 //sts.l DBR,@-<REG_N>
sh4op(i0100_nnnn_1111_0010)
{
	u32 n = GetN(op);

	u32 addr = r[n] - 4;
	WriteMemU32(addr,dbr);
	r[n] = addr;
}

//stc.l GBR,@-<REG_N>
sh4op(i0100_nnnn_0001_0011)
{
	//iNimp("stc.l GBR,@-<REG_N>");
	u32 n = GetN(op);
	
	u32 addr = r[n] - 4;
	WriteMemU32(addr, gbr);
	r[n] = addr;
}


//stc.l VBR,@-<REG_N>
sh4op(i0100_nnnn_0010_0011)
{
	//iNimp("stc.l VBR,@-<REG_N>");
	u32 n = GetN(op);

	u32 addr = r[n] - 4;
	WriteMemU32(addr, vbr);
	r[n] = addr;
}


//stc.l SSR,@-<REG_N>
sh4op(i0100_nnnn_0011_0011)
{
	//iNimp("stc.l SSR,@-<REG_N>");
	u32 n = GetN(op);

	u32 addr = r[n] - 4;
	WriteMemU32(addr, ssr);
	r[n] = addr;
}
//stc.l SGR,@-<REG_N>
sh4op(i0100_nnnn_0011_0010)
{
	//iNimp("stc.l SGR,@-<REG_N>");
	u32 n = GetN(op);

	u32 addr = r[n] - 4;
	WriteMemU32(addr, sgr);
	r[n] = addr;
}


//stc.l SPC,@-<REG_N>
sh4op(i0100_nnnn_0100_0011)
{
	//iNimp("stc.l SPC,@-<REG_N>");
	u32 n = GetN(op);

	u32 addr = r[n] - 4;
	WriteMemU32(addr, spc);
	r[n] = addr;
}

//stc RM_BANK,@-<REG_N>
sh4op(i0100_nnnn_1mmm_0011)
{
	//iNimp("stc RM_BANK,@-<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op) & 0x07;

	u32 addr = r[n] - 4;
	WriteMemU32(addr, r_bank[m]);
	r[n] = addr;
}



//lds.l @<REG_N>+,MACH
sh4op(i0100_nnnn_0000_0110)
{
	u32 n = GetN(op);
	ReadMemU32(mac.h,r[n]);

	r[n] += 4;
}


//lds.l @<REG_N>+,MACL
sh4op(i0100_nnnn_0001_0110)
{
	//iNimp("lds.l @<REG_N>+,MACL ");
	u32 n = GetN(op);
	ReadMemU32(mac.l,r[n]);

	r[n] += 4;
}


//lds.l @<REG_N>+,PR
sh4op(i0100_nnnn_0010_0110)
{
	u32 n = GetN(op);
	ReadMemU32(pr,r[n]);

	r[n] += 4;
}


//lds.l @<REG_N>+,FPUL
sh4op(i0100_nnnn_0101_0110)
{
	//iNimp("lds.l @<REG_N>+,FPU");
	u32 n = GetN(op);

	ReadMemU32(fpul,r[n]);
	r[n] += 4;
}

//lds.l @<REG_N>+,DBR
sh4op(i0100_nnnn_1111_0110)
{
	u32 n = GetN(op);

	ReadMemU32(dbr,r[n]);
	r[n] += 4;
}


//ldc.l @<REG_N>+,GBR
sh4op(i0100_nnnn_0001_0111)
{
	//iNimp("ldc.l @<REG_N>+,GBR");
	u32 n = GetN(op);

	ReadMemU32(gbr,r[n]);
	r[n] += 4;
}


//ldc.l @<REG_N>+,VBR
sh4op(i0100_nnnn_0010_0111)
{
	//iNimp("ldc.l @<REG_N>+,VBR");
	u32 n = GetN(op);

	ReadMemU32(vbr,r[n]);
	r[n] += 4;
}


//ldc.l @<REG_N>+,SSR
sh4op(i0100_nnnn_0011_0111)
{
	//iNimp("ldc.l @<REG_N>+,SSR");
	u32 n = GetN(op);

	ReadMemU32(ssr,r[n]);
	r[n] += 4;
}

//ldc.l @<REG_N>+,SGR
sh4op(i0100_nnnn_0011_0110)
{
	//iNimp("ldc.l @<REG_N>+,SGR");
	u32 n = GetN(op);

	ReadMemU32(sgr,r[n]);
	r[n] += 4;
}

//ldc.l @<REG_N>+,SPC
sh4op(i0100_nnnn_0100_0111)
{
	//iNimp("ldc.l @<REG_N>+,SPC");
	u32 n = GetN(op);

	ReadMemU32(spc,r[n]);
	r[n] += 4;
}


//ldc.l @<REG_N>+,RM_BANK
sh4op(i0100_nnnn_1mmm_0111)
{
	//iNimp("ldc.l @<REG_N>+,R0_BANK");
	u32 n = GetN(op);
	u32 m = GetM(op) & 7;

	ReadMemU32(r_bank[m],r[n]);
	r[n] += 4;
}

//lds <REG_N>,MACH
sh4op(i0100_nnnn_0000_1010)
{
	u32 n = GetN(op);
	mac.h = r[n];
}


//lds <REG_N>,MACL
sh4op(i0100_nnnn_0001_1010)
{
	u32 n = GetN(op);
	mac.l = r[n];
}


//lds <REG_N>,PR
sh4op(i0100_nnnn_0010_1010)
{
	u32 n = GetN(op);
	pr = r[n];
}


//lds <REG_N>,FPUL
sh4op(i0100_nnnn_0101_1010)
{
	u32 n = GetN(op);
	fpul =r[n];
}




//ldc <REG_N>,DBR
sh4op(i0100_nnnn_1111_1010)
{
	u32 n = GetN(op);
	dbr = r[n];
}




//ldc <REG_N>,GBR
sh4op(i0100_nnnn_0001_1110)
{
	u32 n = GetN(op);
	gbr = r[n];
}


//ldc <REG_N>,VBR
sh4op(i0100_nnnn_0010_1110)
{
	//iNimp("ldc <REG_N>,VBR");
	u32 n = GetN(op);

	vbr = r[n];
}


//ldc <REG_N>,SSR
sh4op(i0100_nnnn_0011_1110)
{
	//iNimp("ldc <REG_N>,SSR");
	u32 n = GetN(op);

	ssr = r[n];
}

 //ldc <REG_N>,SGR
sh4op(i0100_nnnn_0011_1010)
{
	//iNimp("ldc <REG_N>,SGR");
	u32 n = GetN(op);

	sgr = r[n];
}

//ldc <REG_N>,SPC
sh4op(i0100_nnnn_0100_1110)
{
	//iNimp("ldc <REG_N>,SPC");
	u32 n = GetN(op);

	spc = r[n];
}


//ldc <REG_N>,RM_BANK
sh4op(i0100_nnnn_1mmm_1110)
{
	//iNimp(op, "ldc <REG_N>,RM_BANK");
	u32 n = GetN(op);
	u32 m = GetM(op) & 7;

	r_bank[m] = r[n];
}

 //
// 5xxx

//mov.l @(<disp>,<REG_M>),<REG_N>
sh4op(i0101_nnnn_mmmm_iiii)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	u32 disp = GetImm4(op) << 2;

	ReadMemBOU32(r[n],r[m],disp);
}

//
// 6xxx
//mov.b @<REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_0000)
{
	u32 n = GetN(op);
	u32 m = GetM(op);

	ReadMemS8(r[n],r[m]);
}


//mov.w @<REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_0001)
{
	//iNimp("mov.w @<REG_M>,<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);
	//r[n] = (u32)(s32)(s16)ReadMem16(r[m]);
	ReadMemS16(r[n] ,r[m]);
}


//mov.l @<REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_0010)
{
	u32 n = GetN(op);
	u32 m = GetM(op);

	ReadMemU32(r[n],r[m]);
}


//mov <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_0011)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	r[n] = r[m];
}


//mov.b @<REG_M>+,<REG_N>
sh4op(i0110_nnnn_mmmm_0100)
{
	//iNimp("mov.b @<REG_M>+,<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);
	//r[n] = (u32)(s32)(s8)ReadMem8(r[m]);
	ReadMemS8(r[n],r[m]);
	if (n != m)
		r[m] += 1;
}


//mov.w @<REG_M>+,<REG_N>
sh4op(i0110_nnnn_mmmm_0101)
{
	//iNimp("mov.w @<REG_M>+,<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);
	//r[n] = (u32)(s16)(u16)ReadMem16(r[m]);
	ReadMemS16(r[n],r[m]);
	if (n != m)
		r[m] += 2;
}


//mov.l @<REG_M>+,<REG_N>
sh4op(i0110_nnnn_mmmm_0110)
{
	u32 n = GetN(op);
	u32 m = GetM(op);


	ReadMemU32(r[n],r[m]);
	if (n != m)
		r[m] += 4;
}

//
//8xxx
 // mov.b R0,@(<disp>,<REG_M>)
sh4op(i1000_0000_mmmm_iiii)
{
	//iNimp("mov.b R0,@(<disp>,<REG_M>)");
	u32 n = GetM(op);
	u32 disp = GetImm4(op);
	WriteMemBOU8(r[n],disp,r[0]);
}


// mov.w R0,@(<disp>,<REG_M>)
sh4op(i1000_0001_mmmm_iiii)
{
	//iNimp("mov.w R0,@(<disp>,<REG_M>)");
	u32 disp = GetImm4(op);
	u32 m = GetM(op);
	WriteMemBOU16(r[m] , (disp << 1),r[0]);
}


// mov.b @(<disp>,<REG_M>),R0
sh4op(i1000_0100_mmmm_iiii)
{
	//iNimp("mov.b @(<disp>,<REG_M>),R0");
	u32 disp = GetImm4(op);
	u32 m = GetM(op);
	//r[0] = (u32)(s8)ReadMem8(r[m] + disp);
	ReadMemBOS8(r[0] ,r[m] , disp);
}


// mov.w @(<disp>,<REG_M>),R0
sh4op(i1000_0101_mmmm_iiii)
{
	//iNimp("mov.w @(<disp>,<REG_M>),R0");
	u32 disp = GetImm4(op);
	u32 m = GetM(op);
	//r[0] = (u32)(s16)ReadMem16(r[m] + (disp << 1));
	ReadMemBOS16(r[0],r[m] , (disp << 1));
}

 //
// 9xxx

//mov.w @(<disp>,PC),<REG_N>
sh4op(i1001_nnnn_iiii_iiii)
{
	u32 n = GetN(op);
	u32 disp = (GetImm8(op));
	//r[n]=(u32)(s32)(s16)ReadMem16((disp<<1) + pc + 4);
	ReadMemS16(r[n],(disp<<1) + next_pc + 2);
}


 //
// Cxxx
// mov.b R0,@(<disp>,GBR)
sh4op(i1100_0000_iiii_iiii)
{
//	iNimp(op, "mov.b R0,@(<disp>,GBR)");
	u32 disp = GetImm8(op);
	WriteMemBOU8(gbr, disp, r[0]);
}


// mov.w R0,@(<disp>,GBR)
sh4op(i1100_0001_iiii_iiii)
{
	//iNimp("mov.w R0,@(<disp>,GBR)");
	u32 disp = GetImm8(op);
	//Write_Word(GBR+(disp<<1),R[0]);
	WriteMemBOU16(gbr , (disp << 1), r[0]);
}


// mov.l R0,@(<disp>,GBR)
sh4op(i1100_0010_iiii_iiii)
{
	// iNimp("mov.l R0,@(<disp>,GBR)");
	u32 disp = (GetImm8(op));
	//u32 source = (disp << 2) + gbr;

	WriteMemBOU32(gbr,(disp << 2), r[0]);
}

// mov.b @(<disp>,GBR),R0
sh4op(i1100_0100_iiii_iiii)
{
//	iNimp(op, "mov.b @(<disp>,GBR),R0");
	u32 disp = GetImm8(op);
	//r[0] = (u32)(s8)ReadMem8(gbr+disp);
	ReadMemBOS8(r[0],gbr,disp);
}


// mov.w @(<disp>,GBR),R0
sh4op(i1100_0101_iiii_iiii)
{
//	iNimp(op, "mov.w @(<disp>,GBR),R0");
	u32 disp = GetImm8(op);
	//r[0] = (u32)(s16)ReadMem16(gbr+(disp<<1) );
	ReadMemBOS16(r[0],gbr,(disp<<1));
}


// mov.l @(<disp>,GBR),R0
sh4op(i1100_0110_iiii_iiii)
{
//	iNimp(op, "mov.l @(<disp>,GBR),R0");
	u32 disp = GetImm8(op);

	ReadMemBOU32(r[0],gbr,(disp<<2));
}


// mova @(<disp>,PC),R0
sh4op(i1100_0111_iiii_iiii)
{
	//u32 disp = (() << 2) + ((pc + 4) & 0xFFFFFFFC);
	r[0] = ((next_pc+2)&0xFFFFFFFC)+(GetImm8(op)<<2);
}

//
// Dxxx

// mov.l @(<disp>,PC),<REG_N>
sh4op(i1101_nnnn_iiii_iiii)
{
	u32 n = GetN(op);
	u32 disp = (GetImm8(op));

	ReadMemU32(r[n],(disp<<2) + ((next_pc+2) & 0xFFFFFFFC));
}
//
// Exxx

// mov #<imm>,<REG_N>
sh4op(i1110_nnnn_iiii_iiii)
{
	u32 n = GetN(op);
	r[n] = (u32)(s32)(s8)(GetSImm8(op));//(u32)(s8)= signextend8 :)
}


 //movca.l R0, @<REG_N>
sh4op(i0000_nnnn_1100_0011)
{
	u32 n = GetN(op);
	WriteMemU32(r[n],r[0]);//at r[n],r[0]
	//iWarn(op, "movca.l R0, @<REG_N>");
}

//clrmac
sh4op(i0000_0000_0010_1000)
{
	//iNimp(op, "clrmac");
	mac.full=0;
}

//braf <REG_N>
sh4op(i0000_nnnn_0010_0011)
{
	u32 n = GetN(op);
	u32 newpc = r[n] + next_pc + 2;//
	ExecuteDelayslot();	//WARN : r[n] can change here
	next_pc = newpc;
}
//bsrf <REG_N>
sh4op(i0000_nnnn_0000_0011)
{
	//TODO: Check pr setting vs real h/w
	u32 n = GetN(op);
	u32 newpc = r[n] + next_pc +2;
	u32 newpr = next_pc + 2;
	
	ExecuteDelayslot(); //WARN : pr and r[n] can change here
	
	pr = newpr;
	next_pc = newpc;
}


 //rte
sh4op(i0000_0000_0010_1011)
{
	//iNimp("rte");
	//sr.SetFull(ssr);
	u32 newpc = spc;
	ExecuteDelayslot_RTE();
	next_pc = newpc;
	if (UpdateSR())
	{
		//FIXME olny if interrupts got on
		UpdateINTC();
	}
}


//rts
sh4op(i0000_0000_0000_1011)
{
	u32 newpc=pr;
	ExecuteDelayslot(); //WARN : pr can change here
	next_pc=newpc;
}

u32 branch_target_s8(u32 op)
{
	return GetSImm8(op)*2 + 2 + next_pc;
}
// bf <bdisp8>
sh4op(i1000_1011_iiii_iiii)
{
	//TODO : Check Me [26/4/05]  | Check DELAY SLOT [28/1/06]
	if (sr.T==0)
	{
		//direct jump
		next_pc = branch_target_s8(op);
	}
}


// bf.s <bdisp8>
sh4op(i1000_1111_iiii_iiii)
{
	if (sr.T==0)
	{
		//delay 1 instruction
		u32 newpc=branch_target_s8(op);
		ExecuteDelayslot();
		next_pc = newpc;
	}
}


// bt <bdisp8>
sh4op(i1000_1001_iiii_iiii)
{
	if (sr.T != 0)
	{
		//direct jump
		next_pc = branch_target_s8(op);
	}
}


// bt.s <bdisp8>
sh4op(i1000_1101_iiii_iiii)
{
	if (sr.T != 0)
	{
		//delay 1 instruction
		u32 newpc=branch_target_s8(op);
		ExecuteDelayslot();
		next_pc = newpc;
	}
}

u32 branch_target_s12(u32 op)
{
	return GetSImm12(op)*2 + 2 + next_pc;
}

// bra <bdisp12>
sh4op(i1010_iiii_iiii_iiii)
{
	u32 newpc = branch_target_s12(op);//(u32) ((  ((s16)((GetImm12(op))<<4)) >>3)  + pc + 4);//(s16<<4,>>4(-1*2))
	ExecuteDelayslot();
	next_pc=newpc;
}

// bsr <bdisp12>
sh4op(i1011_iiii_iiii_iiii)
{
	//TODO: check pr vs real h/w
	u32 newpr = next_pc + 2; //return after delayslot
	u32 newpc = branch_target_s12(op);
	ExecuteDelayslot();

	pr = newpr;
	next_pc=newpc;
}

// trapa #<imm>
sh4op(i1100_0011_iiii_iiii)
{
	//printf("trapa 0x%X\n",(GetImm8(op) << 2));
	CCN_TRA = (GetImm8(op) << 2);
	Do_Exception(next_pc,0x160,0x100);
}

//jmp @<REG_N>
sh4op(i0100_nnnn_0010_1011)
{
	u32 n = GetN(op);

	u32 newpc=r[n];
	ExecuteDelayslot(); //r[n] can change here
	next_pc=newpc;
}

//jsr @<REG_N>
sh4op(i0100_nnnn_0000_1011)
{
	u32 n = GetN(op);

	//TODO: check pr vs real h/w
	u32 newpr = next_pc + 2;   //return after delayslot
	u32 newpc= r[n];
	ExecuteDelayslot(); //r[n]/pr can change here

	pr = newpr;
	next_pc=newpc;
}

//sleep
sh4op(i0000_0000_0001_1011)
{
	//iNimp("Sleep");
	//just wait for an Interrupt

	int i=0,s=1;

	while (!UpdateSystem_INTC())//448
	{
		if (i++>1000)
		{
			s=0;
			break;
		}
	}
	//if not Interrupted , we must rexecute the sleep
	if (s==0)
		next_pc-=2;// re execute sleep

}


// sub <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_1000)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	//rn=(s32)r[n];
	//rm=(s32)r[m];
	r[n] -=r[m];
	//r[n]=(u32)rn;
}

//add <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_1100)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	r[n] +=r[m];
}

 //
// 7xxx

//add #<imm>,<REG_N>
sh4op(i0111_nnnn_iiii_iiii)
{
	u32 n = GetN(op);
	s32 stmp1 = GetSImm8(op);
	r[n] +=stmp1;
}

//Bitwise logical operations
//

//and <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1001)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	r[n] &= r[m];
}

//xor <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1010)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	r[n] ^= r[m];
}

//or <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1011)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	r[n] |= r[m];
}


//shll2 <REG_N>
sh4op(i0100_nnnn_0000_1000)
{
	u32 n = GetN(op);
	r[n] <<= 2;
}


//shll8 <REG_N>
sh4op(i0100_nnnn_0001_1000)
{//ToDo : Check This [26/4/05]
	u32 n = GetN(op);
	r[n] <<= 8;
}


//shll16 <REG_N>
sh4op(i0100_nnnn_0010_1000)
{//ToDo : Check This [26/4/05]
	u32 n = GetN(op);
	r[n] <<= 16;
}


//shlr2 <REG_N>
sh4op(i0100_nnnn_0000_1001)
{//ToDo : Check This [26/4/05]
	u32 n = GetN(op);
	r[n] >>= 2;
}


//shlr8 <REG_N>
sh4op(i0100_nnnn_0001_1001)
{
	//iNimp("shlr8 <REG_N>");
	u32 n = GetN(op);
	r[n] >>= 8;
}


//shlr16 <REG_N>
sh4op(i0100_nnnn_0010_1001)
{
	u32 n = GetN(op);
	r[n] >>= 16;
}

// and #<imm>,R0
sh4op(i1100_1001_iiii_iiii)
{//ToDo : Check This [26/4/05]
	//iNimp("and #<imm>,R0");
	u32 imm = GetImm8(op);
	r[0] &= imm;
}


// xor #<imm>,R0
sh4op(i1100_1010_iiii_iiii)
{
	//iNimp("xor #<imm>,R0");
	u32  imm  = GetImm8(op);
	r[0] ^= imm;
}


// or #<imm>,R0
sh4op(i1100_1011_iiii_iiii)
{//ToDo : Check This [26/4/05]
	//iNimp("or #<imm>,R0");
	u32 imm = GetImm8(op);
	r[0] |= imm;
}



//TODO : move it somewhere better
//nop
sh4op(i0000_0000_0000_1001)
{
	//no operation xD XD .. i just love this opcode ..
	//what ? you expected something fancy or smth ?
}

//************************ TLB/Cache ************************
//ldtlb
sh4op(i0000_0000_0011_1000)
{
	//printf("ldtlb %d/%d\n",CCN_MMUCR.URC,CCN_MMUCR.URB);
	UTLB[CCN_MMUCR.URC].Data=CCN_PTEL;
	UTLB[CCN_MMUCR.URC].Address=CCN_PTEH;

	UTLB_Sync(CCN_MMUCR.URC);
}

//ocbi @<REG_N>
sh4op(i0000_nnnn_1001_0011)
{
	u32 n = GetN(op);
	//printf("ocbi @0x%08X \n",r[n]);
}

//ocbp @<REG_N>
sh4op(i0000_nnnn_1010_0011)
{
	u32 n = GetN(op);
	//printf("ocbp @0x%08X \n",r[n]);
}

//ocbwb @<REG_N>
sh4op(i0000_nnnn_1011_0011)
{
	u32 n = GetN(op);
	//printf("ocbwb @0x%08X \n",r[n]);
}

//pref @<REG_N>
template<bool mmu_on>
INLINE void DYNACALL do_sqw(u32 Dest)
{
	//TODO : Check for enabled store queues ?
	u32 Address;

	//Translate the SQ addresses as needed
	if (mmu_on)
	{
		if (!mmu_TranslateSQW(Dest, &Address))
			return;
	}
	else
	{

#if HOST_CPU ==CPU_X86
		//sanity/optimisation check
		verify(CCN_QACR_TR[0]==CCN_QACR_TR[1]);
#endif

		u32 QACR = CCN_QACR_TR[0];
		/*
		//sq1 ? if so use QACR1
		//(QACR1==QACR0 in all stuff i've tested)
		if (Dest& 0x20)
			QACR = CCN_QACR_TR[1];
		*/
		//QACR has already 0xE000_0000
		Address= QACR+(Dest&~0x1f);
	}

	if (((Address >> 26) & 0x7) != 4)//Area 4
	{
		u8* sq=&sq_both[Dest& 0x20];
		WriteMemBlock_nommu_sq(Address,(u32*)sq);
	}
	else
	{
		TAWriteSQ(Address,sq_both);
	}
}

void DYNACALL do_sqw_mmu(u32 dst) { do_sqw<true>(dst); }
#if HOST_CPU != CPU_ARM
//yes, this micro optimization makes a difference
extern "C" void DYNACALL do_sqw_nommu_area_3(u32 dst,u8* sqb)
{
	u8* pmem=sqb+512+0x0C000000;

	memcpy((u64*)&pmem[dst&(RAM_MASK-0x1F)],(u64*)&sqb[dst & 0x20],32);
}
#endif

extern "C" void DYNACALL do_sqw_nommu_area_3_nonvmem(u32 dst,u8* sqb)
{
	u8* pmem = mem_b.data;

	memcpy((u64*)&pmem[dst&(RAM_MASK-0x1F)],(u64*)&sqb[dst & 0x20],32);
}

void DYNACALL do_sqw_nommu_full(u32 dst, u8* sqb) { do_sqw<false>(dst); }

sh4op(i0000_nnnn_1000_0011)
{
	u32 n = GetN(op);
	u32 Dest = r[n];

	if ((Dest>>26) == 0x38) //Store Queue
	{
		if (CCN_MMUCR.AT)
			do_sqw<true>(Dest);
		else
			do_sqw<false>(Dest);
	}
}


//************************ Set/Get T/S ************************
//sets
sh4op(i0000_0000_0101_1000)
{
	sr.S = 1;
}

//clrs
sh4op(i0000_0000_0100_1000)
{
	sr.S = 0;
}

//sett
sh4op(i0000_0000_0001_1000)
{
	sr.T = 1;
}

//clrt
sh4op(i0000_0000_0000_1000)
{
	sr.T = 0;
}

//movt <REG_N>
sh4op(i0000_nnnn_0010_1001)
{
	u32 n = GetN(op);
	r[n] = sr.T;
}

//************************ Reg Compares ************************
//cmp/pz <REG_N>
sh4op(i0100_nnnn_0001_0001)
{
	u32 n = GetN(op);

	if (((s32)r[n]) >= 0)
		sr.T = 1;
	else
		sr.T = 0;
}

//cmp/pl <REG_N>
sh4op(i0100_nnnn_0001_0101)
{
	//iNimp("cmp/pl <REG_N>");
	u32 n = GetN(op);
	if ((s32)r[n] > 0)
		sr.T = 1;
	else
		sr.T = 0;
}

//cmp/eq #<imm>,R0
sh4op(i1000_1000_iiii_iiii)
{
	u32 imm = (u32)(s32)(GetSImm8(op));
	if (r[0] == imm)
		sr.T =1;
	else
		sr.T =0;
}

//cmp/eq <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_0000)
{
	//iNimp("cmp/eq <REG_M>,<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);

	if (r[m] == r[n])
		sr.T = 1;
	else
		sr.T = 0;
}

//cmp/hs <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_0010)
{//ToDo : Check Me [26/4/05]
	u32 n = GetN(op);
	u32 m = GetM(op);
	if (r[n] >= r[m])
		sr.T=1;
	else
		sr.T=0;
}

//cmp/ge <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_0011)
{
	//iNimp("cmp/ge <REG_M>,<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);
	if ((s32)r[n] >= (s32)r[m])
		sr.T = 1;
	else
		sr.T = 0;
}

//cmp/hi <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_0110)
{
	u32 n = GetN(op);
	u32 m = GetM(op);

	if (r[n] > r[m])
		sr.T=1;
	else
		sr.T=0;
}

//cmp/gt <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_0111)
{
	//iNimp("cmp/gt <REG_M>,<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);

	if (((s32)r[n]) > ((s32)r[m]))
		sr.T = 1;
	else
		sr.T = 0;
}

//cmp/str <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1100)
{
	//T -> 1 if -any- bytes are equal
	u32 n = GetN(op);
	u32 m = GetM(op);

	u32 temp;
	u32 HH, HL, LH, LL;

	temp = r[n] ^ r[m];

	HH=(temp&0xFF000000)>>24;
	HL=(temp&0x00FF0000)>>16;
	LH=(temp&0x0000FF00)>>8;
	LL=temp&0x000000FF;
	HH=HH&&HL&&LH&&LL;
	if (HH==0)
		sr.T=1;
	else
		sr.T=0;
}

//tst #<imm>,R0
sh4op(i1100_1000_iiii_iiii)
{
	//iNimp("tst #<imm>,R0");
	u32 utmp1 = r[0] & GetImm8(op);
	if (utmp1 == 0)
		sr.T = 1;
	else
		sr.T = 0;
}
//tst <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1000)
{//ToDo : Check This [26/4/05]
	u32 n = GetN(op);
	u32 m = GetM(op);

	if ((r[n] & r[m])!=0)
		sr.T=0;
	else
		sr.T=1;

}
//************************ mulls! ************************
//mulu.w <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1110)
{
	//iNimp("mulu.w <REG_M>,<REG_N>");//check  ++
	u32 n = GetN(op);
	u32 m = GetM(op);
	mac.l=((u16)r[n])*
		((u16)r[m]);
}

//muls.w <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1111)
{
	//iNimp("muls <REG_M>,<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);

	mac.l = (u32)(((s16)(u16)r[n]) * ((s16)(u16)r[m]));
}
//dmulu.l <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_0101)
{
	//iNimp("dmulu.l <REG_M>,<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);

	mac.full = (u64)r[n] * (u64)r[m];
}

//dmuls.l <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_1101)
{
	//iNimp("dmuls.l <REG_M>,<REG_N>");//check ++
	u32 n = GetN(op);
	u32 m = GetM(op);

	mac.full = (s64)(s32)r[n] * (s64)(s32)r[m];
}


//mac.w @<REG_M>+,@<REG_N>+
sh4op(i0100_nnnn_mmmm_1111)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	if (sr.S!=0)
	{
		printf("mac.w @<REG_M>+,@<REG_N>+ : s=%d\n",sr.S);
	}
	else
	{
		s32 rm,rn;

		rn = (s32)(s16)ReadMem16(r[n]);
		r[n]+=2;
		//if (n==m)
		//{
		//	r[n]+=2;
		//	r[m]+=2;
		//}
		rm = (s32)(s16)ReadMem16(r[m]);

		r[m]+=2;

		s32 mul=rm * rn;
		mac.full+=(s64)mul;
	}
}
//mac.l @<REG_M>+,@<REG_N>+
sh4op(i0000_nnnn_mmmm_1111)
{
	//iNimp("mac.l @<REG_M>+,@<REG_N>+");
	u32 n = GetN(op);
	u32 m = GetM(op);
	s32 rm, rn;

	verify(sr.S==0);

	ReadMemS32(rm,r[m]);
	r[m] += 4;
	ReadMemS32(rn,r[n]);
	r[n] += 4;

	mac.full += (s64)rm * (s64)rn;

	//printf("%I64u %I64u | %d %d | %d %d\n",mac,mul,macl,mach,rm,rn);
}

//mul.l <REG_M>,<REG_N>
sh4op(i0000_nnnn_mmmm_0111)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	mac.l = (u32)((((s32)r[n]) * ((s32)r[m])));
}
//************************ Div ! ************************
//div0u
sh4op(i0000_0000_0001_1001)
{
	sr.Q = 0;
	sr.M = 0;
	sr.T = 0;
}
//div0s <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_0111)
{//ToDo : Check This [26/4/05]
	u32 n = GetN(op);
	u32 m = GetM(op);

	//new implementation
	sr.Q=r[n]>>31;
	sr.M=r[m]>>31;
	sr.T=sr.M^sr.Q;
	return;
	/*
	if ((r[n] & 0x80000000)!=0)
	sr.Q = 1;
	else
	sr.Q = 0;

	if ((r[m] & 0x80000000)!=0)
		sr.M = 1;
	else
		sr.M = 0;

	if (sr.Q == sr.M)
		sr.T = 0;
	else
		sr.T = 1;
		*/
}

//div1 <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_0100)
{
	u32 n=GetN(op);
	u32 m=GetM(op);

	unsigned long tmp0, tmp2;
	unsigned char old_q, tmp1;

	old_q = sr.Q;
	sr.Q = (u8)((0x80000000 & r[n]) !=0);

	r[n] <<= 1;
	r[n] |= (unsigned long)sr.T;

	tmp0 = r[n];	// this need only be done once here ..
	tmp2 = r[m];

	if( 0 == old_q )
	{
		if( 0 == sr.M )
		{
			r[n] -= tmp2;
			tmp1	= (r[n]>tmp0);
			sr.Q	= (sr.Q==0) ? tmp1 : (u8)(tmp1==0) ;
		}
		else
		{
			r[n] += tmp2;
			tmp1	=(r[n]<tmp0);
			sr.Q	= (sr.Q==0) ? (u8)(tmp1==0) : tmp1 ;
		}
	}
	else
	{
		if( 0 == sr.M )
		{
			r[n] += tmp2;
			tmp1	=(r[n]<tmp0);
			sr.Q	= (sr.Q==0) ? tmp1 : (u8)(tmp1==0) ;
		}
		else
		{
			r[n] -= tmp2;
			tmp1	=(r[n]>tmp0);
			sr.Q	= (sr.Q==0) ? (u8)(tmp1==0) : tmp1 ;
		}
	}
	sr.T = (sr.Q==sr.M);
}

//************************ Simple maths ************************
//addc <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_1110)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	u32 tmp1 = r[n] + r[m];
	u32 tmp0 = r[n];

	r[n] = tmp1 + sr.T;

	if (tmp0 > tmp1)
		sr.T = 1;
	else
		sr.T = 0;

	if (tmp1 > r[n])
		sr.T = 1;
}

// addv <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_1111)
{
	printf("WARN: addv <REG_M>,<REG_N> used, %04X\n",op);
	//Retail game "Twinkle Star Sprites" "uses" this opcode.
	//iNimp(op, "addv <REG_M>,<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);
	s64 br=(s64)(s32)r[n]+(s64)(s32)r[m];
	//u32 rm=r[m];
	//u32 rn=r[n];
	/*__asm
	{
		mov eax,rm;
		mov ecx,rn;
		add eax,ecx;
		seto sr.T;
		mov rn,eax;
	};*/
	//r[n]=rn;

	if (br >=0x80000000)
		sr.T=1;
	else if (br < (s64) (0xFFFFFFFF80000000u))
		sr.T=1;
	else
		sr.T=0;
	/*if (br>>32)
		sr.T=1;
	else
		sr.T=0;*/

	r[n]+=r[m];
}

//subc <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_1010)
{//ToDo : Check This [26/4/05]
	//iNimp(op,"subc <REG_M>,<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);

	u32 tmp1 = r[n] - r[m];
	u32 tmp0 = r[n];
	r[n] = tmp1 - sr.T;

	if (tmp0 < tmp1)
		sr.T=1;
	else
		sr.T=0;

	if (tmp1 < r[n])
		sr.T=1;
}

//subv <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_1011)
{
	printf("WARN: subv <REG_M>,<REG_N> used, %04X\n",op);
	//Retail game "Twinkle Star Sprites" "uses" this opcode.
	//iNimp(op, "subv <REG_M>,<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);
	s64 br=(s64)(s32)r[n]-(s64)(s32)r[m];

	if (br >=0x80000000)
		sr.T=1;
	else if (br < (s64) (0xFFFFFFFF80000000u))
		sr.T=1;
	else
		sr.T=0;
	/*if (br>>32)
		sr.T=1;
	else
		sr.T=0;*/

	r[n]-=r[m];
	//u32 rm=r[m];
	//u32 rn=r[n];
	/*__asm
	{
		mov eax,rm;
		mov ecx,rn;
		sub eax,ecx;
		seto sr.T;
		mov rn,eax;
	};*/
	//r[n]=rn;
}
//dt <REG_N>
sh4op(i0100_nnnn_0001_0000)
{
	u32 n = GetN(op);
	r[n]-=1;
	if (r[n] == 0)
		sr.T=1;
	else
		sr.T=0;
}

//negc <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1010)
{
	//iNimp("negc <REG_M>,<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);

	//r[n]=-r[m]-sr.T;
	u32 tmp=0 - r[m];
	r[n]=tmp - sr.T;

	if (0<tmp)
		sr.T=1;
	else
		sr.T=0;

	if (tmp<r[n])
		sr.T=1;
}


//neg <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1011)
{//ToDo : Check This [26/4/05]
	u32 n = GetN(op);
	u32 m = GetM(op);
	r[n] = -r[m];
}

//not <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_0111)
{
	//iNimp("not <REG_M>,<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);

	r[n] = ~r[m];
}


//************************ shifts/rotates ************************
//shll <REG_N>
sh4op(i0100_nnnn_0000_0000)
{//ToDo : Check This [26/4/05]
	u32 n = GetN(op);

	sr.T = r[n] >> 31;
	r[n] <<= 1;
}
//shal <REG_N>
sh4op(i0100_nnnn_0010_0000)
{
	u32 n=GetN(op);
	sr.T=r[n]>>31;
	r[n]=((s32)r[n])<<1;
}


//shlr <REG_N>
sh4op(i0100_nnnn_0000_0001)
{//ToDo : Check This [26/4/05]
	u32 n = GetN(op);
	sr.T = r[n] & 0x1;
	r[n] >>= 1;
}

//shar <REG_N>
sh4op(i0100_nnnn_0010_0001)
{//ToDo : Check This [26/4/05] x2
	//iNimp("shar <REG_N>");
	u32 n = GetN(op);

	sr.T=r[n] & 1;
	r[n]=((s32)r[n])>>1;
}

//shad <REG_M>,<REG_N>
sh4op(i0100_nnnn_mmmm_1100)
{
	//iNimp(op,"shad <REG_M>,<REG_N>");
	u32 n = GetN(op);
	u32 m = GetM(op);
	u32 sgn = r[m] & 0x80000000;
	if (sgn == 0)
		r[n] <<= (r[m] & 0x1F);
	else if ((r[m] & 0x1F) == 0)
	{
		r[n]=((s32)r[n])>>31;
	}
	else
		r[n] = ((s32)r[n]) >> ((~r[m] & 0x1F) + 1);
}


//shld <REG_M>,<REG_N>
sh4op(i0100_nnnn_mmmm_1101)
{
	//iNimp("shld <REG_M>,<REG_N>");

	u32 n = GetN(op);
	u32 m = GetM(op);
	u32 sgn = r[m] & 0x80000000;
	if (sgn == 0)
		r[n] <<= (r[m] & 0x1F);
	else if ((r[m] & 0x1F) == 0)
	{
		r[n] = 0;
	}
	else
		r[n] = ((u32)r[n]) >> ((~r[m] & 0x1F) + 1);	//isn't this the same as -r[m] ?
}



//rotcl <REG_N>
sh4op(i0100_nnnn_0010_0100)
{
	//iNimp("rotcl <REG_N>");
	u32 n = GetN(op);
	u32 t;

	t = sr.T;

	sr.T = r[n] >> 31;

	r[n] <<= 1;

	r[n]|=t;
}


//rotl <REG_N>
sh4op(i0100_nnnn_0000_0100)
{
	//iNimp("rotl <REG_N>");
	u32 n = GetN(op);

	sr.T=r[n]>>31;

	r[n] <<= 1;

	r[n]|=sr.T;
}

//rotcr <REG_N>
sh4op(i0100_nnnn_0010_0101)
{
	//iNimp("rotcr <REG_N>");
	u32 n = GetN(op);
	u32 t;


	t = r[n] & 0x1;

	r[n] >>= 1;

	r[n] |=(sr.T)<<31;

	sr.T = t;
}


//rotr <REG_N>
sh4op(i0100_nnnn_0000_0101)
{
	//iNimp("rotr <REG_N>");
	u32 n = GetN(op);
	sr.T = r[n] & 0x1;
	r[n] >>= 1;
	r[n] |= ((sr.T) << 31);
}
//************************ byte reorder/sign ************************
//swap.b <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1000)
{
	//iNimp("swap.b <REG_M>,<REG_N>");
	u32 m = GetM(op);
	u32 n = GetN(op);

	u32 rg=r[m];
	r[n] = (rg & 0xFFFF0000) | ((rg&0xFF)<<8) | ((rg>>8)&0xFF);
}


//swap.w <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1001)
{
	u32 n = GetN(op);
	u32 m = GetM(op);

	u16 t = (u16)(r[m]>>16);
	r[n] = (r[m] << 16) | t;
}



//extu.b <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1100)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	r[n] = (u32)(u8)r[m];
}


//extu.w <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1101)
{
	u32 n = GetN(op);
	u32 m = GetM(op);
	r[n] =(u32)(u16) r[m];
}


//exts.b <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1110)
{
	u32 n = GetN(op);
	u32 m = GetM(op);

	r[n] = (u32)(s32)(s8)(u8)(r[m]);

}


//exts.w <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1111)
{
	u32 n = GetN(op);
	u32 m = GetM(op);

	r[n] = (u32)(s32)(s16)(u16)(r[m]);
}


//xtrct <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1101)
{
	u32 n = GetN(op);
	u32 m = GetM(op);

	r[n] = ((r[n] >> 16) & 0xFFFF) | ((r[m] << 16) & 0xFFFF0000);
}


//************************ xxx.b #<imm>,@(R0,GBR) ************************
//tst.b #<imm>,@(R0,GBR)
sh4op(i1100_1100_iiii_iiii)
{
	printf("WARN: tst.b #<imm>,@(R0,GBR) used, %04X\n",op);
	//Retail game "Twinkle Star Sprites" "uses" this opcode.
	u32 imm=GetImm8(op);

	u32 temp = (u8)ReadMem8(gbr+r[0]);

	temp &= imm;

	if (temp==0)
		sr.T=1;
	else
		sr.T=0;
}


//and.b #<imm>,@(R0,GBR)
sh4op(i1100_1101_iiii_iiii)
{
	u8 temp = (u8)ReadMem8(gbr+r[0]);

	temp &= GetImm8(op);

	WriteMem8(gbr +r[0], temp);
}


//xor.b #<imm>,@(R0,GBR)
sh4op(i1100_1110_iiii_iiii)
{
	u8 temp = (u8)ReadMem8(gbr+r[0]);

	temp ^= GetImm8(op);

	WriteMem8(gbr +r[0], temp);
}


//or.b #<imm>,@(R0,GBR)
sh4op(i1100_1111_iiii_iiii)
{
	u8 temp = (u8)ReadMem8(gbr+r[0]);

	temp |= GetImm8(op);

	WriteMem8(gbr+r[0], temp);
}
//tas.b @<REG_N>
sh4op(i0100_nnnn_0001_1011)
{
	//iNimp("tas.b @<REG_N>");
	u32 n = GetN(op);
	u8 val;

	val=(u8)ReadMem8(r[n]);

	u32 srT;
	if (val == 0)
		srT = 1;
	else
		srT = 0;

	val |= 0x80;

	WriteMem8(r[n], val);

	sr.T=srT;
}

//************************ Opcodes that read/write the status registers ************************
//stc SR,<REG_N>
sh4op(i0000_nnnn_0000_0010)//0002
{
	u32 n = GetN(op);
	r[n] = sr.GetFull();
}

 //sts FPSCR,<REG_N>
sh4op(i0000_nnnn_0110_1010)
{
	//iNimp("sts FPSCR,<REG_N>");
	u32 n = GetN(op);
	r[n] = fpscr.full;
	UpdateFPSCR();
}

//sts.l FPSCR,@-<REG_N>
sh4op(i0100_nnnn_0110_0010)
{
	u32 n = GetN(op);
	r[n] -= 4;
	WriteMemU32(r[n],fpscr.full);
}

//stc.l SR,@-<REG_N>
sh4op(i0100_nnnn_0000_0011)
{
	//iNimp("stc.l SR,@-<REG_N>");
	u32 n = GetN(op);
	r[n] -= 4;
	WriteMemU32(r[n], sr.GetFull());
}

//lds.l @<REG_N>+,FPSCR
sh4op(i0100_nnnn_0110_0110)
{
	u32 n = GetN(op);

	ReadMemU32(fpscr.full,r[n]);

	UpdateFPSCR();
	r[n] += 4;
}

//ldc.l @<REG_N>+,SR
sh4op(i0100_nnnn_0000_0111)
{
	//iNimp("ldc.l @<REG_N>+,SR");
	u32 n = GetN(op);

	u32 sr_t;
	ReadMemU32(sr_t,r[n]);

	sr.SetFull(sr_t);
	r[n] += 4;
	if (UpdateSR())
	{
		UpdateINTC();
	}
}

//lds <REG_N>,FPSCR
sh4op(i0100_nnnn_0110_1010)
{
	u32 n = GetN(op);
	fpscr.full = r[n];
	UpdateFPSCR();
}

//ldc <REG_N>,SR
sh4op(i0100_nnnn_0000_1110)
{
	u32 n = GetN(op);
	sr.SetFull(r[n]);
	if (UpdateSR())
	{
		UpdateINTC();
	}
}


//Not implt
sh4op(iNotImplemented)
{
#ifndef NO_MMU
	printf("iNimp %04X\n", op);
	SH4ThrownException ex = { next_pc - 2, 0x180, 0x100 };
	throw ex;
#else
	cpu_iNimp(op, "Unknown opcode");
#endif
	
}

