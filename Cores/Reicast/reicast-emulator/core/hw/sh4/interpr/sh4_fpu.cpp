#include "types.h"
#include <math.h>
#include <float.h>


#include "sh4_opcodes.h"
#include "../sh4_core.h"
#include "../sh4_rom.h"

#include "hw/sh4/sh4_mem.h"


#define sh4op(str) void DYNACALL str (u32 op)
#define GetN(str)     ((str>>8) & 0xf)
#define GetM(str)     ((str>>4) & 0xf)
#define GetImm4(str)  ((str>>0) & 0xf)
#define GetImm8(str)  ((str>>0) & 0xff)
#define GetImm12(str) ((str>>0) & 0xfff)

#define GetDN(opc)  ((op&0x0F00)>>9)
#define GetDM(opc)  ((op&0x00F0)>>5)

#define pi (3.14159265f)

void iNimp(const char*str);

#define IS_DENORMAL(f) (((*(f))&0x7f800000) == 0)

#define ReadMemU64(to,addr) to=ReadMem64(addr)
#define ReadMemU32(to,addr) to=ReadMem32(addr)
#define ReadMemS32(to,addr) to=(s32)ReadMem32(addr)
#define ReadMemS16(to,addr) to=(u32)(s32)(s16)ReadMem16(addr)
#define ReadMemS8(to,addr)  to=(u32)(s32)(s8)ReadMem8(addr)

//Base,offset format
#define ReadMemBOU32(to,addr,offset)        ReadMemU32(to,addr+offset)
#define ReadMemBOS16(to,addr,offset)        ReadMemS16(to,addr+offset)
#define ReadMemBOS8(to,addr,offset)         ReadMemS8(to,addr+offset)

//Write Mem Macros
#define WriteMemU64(addr,data)              WriteMem64(addr,(u64)data)
#define WriteMemU32(addr,data)              WriteMem32(addr,(u32)data)
#define WriteMemU16(addr,data)              WriteMem16(addr,(u16)data)
#define WriteMemU8(addr,data)               WriteMem8(addr,(u8)data)

//Base,offset format
#define WriteMemBOU32(addr,offset,data)     WriteMemU32(addr+offset,data)
#define WriteMemBOU16(addr,offset,data)     WriteMemU16(addr+offset,data)
#define WriteMemBOU8(addr,offset,data)      WriteMemU8(addr+offset,data)

INLINE void Denorm32(float &value)
{
	if (fpscr.DN)
	{
		u32* v=(u32*)&value;
		if (IS_DENORMAL(v) && (*v&0x7fFFFFFF)!=0)
		{
			*v&=0x80000000;
			//printf("Denormal ..\n");
		}
		if ((*v<=0x007FFFFF) && *v>0)
		{
			*v=0;
			printf("Fixed +denorm\n");
		}
		else if ((*v<=0x807FFFFF) && *v>0x80000000)
		{
			*v=0x80000000;
			printf("Fixed -denorm\n");
		}
	}
}


#define CHECK_FPU_32(v) //Denorm32(v)
#define CHECK_FPU_64(v)


//fadd <FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_0000)
{
	if (fpscr.PR == 0)
	{
		u32 n = GetN(op);
		u32 m = GetM(op);
		fr[n] += fr[m];
		//CHECK_FPU_32(fr[n]);
	}
	else
	{
		u32 n = (op >> 9) & 0x07;
		u32 m = (op >> 5) & 0x07;

		double drn=GetDR(n), drm=GetDR(m);
		drn += drm;
		CHECK_FPU_64(drn);
		SetDR(n,drn);
	}
}

//fsub <FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_0001)
{
	if (fpscr.PR == 0)
	{
		u32 n = GetN(op);
		u32 m = GetM(op);

		fr[n] -= fr[m];
		CHECK_FPU_32(fr[n]);
	}
	else
	{
		u32 n = (op >> 9) & 0x07;
		u32 m = (op >> 5) & 0x07;

		double drn=GetDR(n), drm=GetDR(m);
		drn-=drm;
		//dr[n] -= dr[m];
		SetDR(n,drn);
	}
}
//fmul <FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_0010)
{
	if (fpscr.PR == 0)
	{
		u32 n = GetN(op);
		u32 m = GetM(op);
		fr[n] *= fr[m];
		CHECK_FPU_32(fr[n]);
	}
	else
	{
		u32 n = (op >> 9) & 0x07;
		u32 m = (op >> 5) & 0x07;

		double drn=GetDR(n), drm=GetDR(m);
		drn*=drm;
		//dr[n] *= dr[m];
		SetDR(n,drn);
	}
}
//fdiv <FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_0011)
{
	if (fpscr.PR == 0)
	{
		u32 n = GetN(op);
		u32 m = GetM(op);

		fr[n] /= fr[m];

		CHECK_FPU_32(fr[n]);
	}
	else
	{
		u32 n = (op >> 9) & 0x07;
		u32 m = (op >> 5) & 0x07;

		double drn=GetDR(n), drm=GetDR(m);
		drn/=drm;
		SetDR(n,drn);
	}
}
//fcmp/eq <FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_0100)
{
	if (fpscr.PR == 0)
	{
		u32 n = GetN(op);
		u32 m = GetM(op);

		sr.T = !!(fr[m] == fr[n]);
	}
	else
	{
		u32 n = (op >> 9) & 0x07;
		u32 m = (op >> 5) & 0x07;

		sr.T = !!(GetDR(m) == GetDR(n));
	}
}
//fcmp/gt <FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_0101)
{
	if (fpscr.PR == 0)
	{
		u32 n = GetN(op);
		u32 m = GetM(op);

		if (fr[n] > fr[m])
			sr.T = 1;
		else
			sr.T = 0;
	}
	else
	{
		u32 n = (op >> 9) & 0x07;
		u32 m = (op >> 5) & 0x07;

		if (GetDR(n) > GetDR(m))
			sr.T = 1;
		else
			sr.T = 0;
	}
}
//All memory opcodes are here
//fmov.s @(R0,<REG_M>),<FREG_N>
sh4op(i1111_nnnn_mmmm_0110)
{
	if (fpscr.SZ == 0)
	{
		u32 n = GetN(op);
		u32 m = GetM(op);

		ReadMemU32(fr_hex[n],r[m] + r[0]);
	}
	else
	{
		u32 n = GetN(op)>>1;
		u32 m = GetM(op);
		if (((op >> 8) & 0x1) == 0)
		{
			ReadMemU64(dr_hex[n],r[m] + r[0]);
		}
		else
		{
			ReadMemU64(xd_hex[n],r[m] + r[0]);
		}
	}
}


//fmov.s <FREG_M>,@(R0,<REG_N>)
sh4op(i1111_nnnn_mmmm_0111)
{
	if (fpscr.SZ == 0)
	{
		u32 n = GetN(op);
		u32 m = GetM(op);

		WriteMem32(r[0] + r[n], fr_hex[m]);
	}
	else
	{
		u32 n = GetN(op);
		u32 m = GetM(op)>>1;
		if (((op >> 4) & 0x1) == 0)
		{
			WriteMemU64(r[n] + r[0],dr_hex[m]);
		}
		else
		{
			WriteMemU64(r[n] + r[0],xd_hex[m]);
		}
	}
}


//fmov.s @<REG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_1000)
{
	if (fpscr.SZ == 0)
	{
		u32 n = GetN(op);
		u32 m = GetM(op);
		ReadMemU32(fr_hex[n],r[m]);
	}
	else
	{
		u32 n = GetN(op)>>1;
		u32 m = GetM(op);
		if (((op >> 8) & 0x1) == 0)
		{
			ReadMemU64(dr_hex[n],r[m]);
		}
		else
		{
			ReadMemU64(xd_hex[n],r[m]);
		}
	}
}


//fmov.s @<REG_M>+,<FREG_N>
sh4op(i1111_nnnn_mmmm_1001)
{
	if (fpscr.SZ == 0)
	{
		u32 n = GetN(op);
		u32 m = GetM(op);

		ReadMemU32(fr_hex[n],r[m]);
		r[m] += 4;
	}
	else
	{
		u32 n = GetN(op)>>1;
		u32 m = GetM(op);
		if (((op >> 8) & 0x1) == 0)
		{
			ReadMemU64(dr_hex[n],r[m]);
		}
		else
		{
			ReadMemU64(xd_hex[n],r[m] );
		}
		r[m] += 8;
	}
}


//fmov.s <FREG_M>,@<REG_N>
sh4op(i1111_nnnn_mmmm_1010)
{
	if (fpscr.SZ == 0)
	{
		u32 n = GetN(op);
		u32 m = GetM(op);
		WriteMemU32(r[n], fr_hex[m]);
	}
	else
	{
		u32 n = GetN(op);
		u32 m = GetM(op)>>1;

		if (((op >> 4) & 0x1) == 0)
		{
			WriteMemU64(r[n], dr_hex[m]);
		}
		else
		{
			WriteMemU64(r[n], xd_hex[m]);
		}

	}
}

//fmov.s <FREG_M>,@-<REG_N>
sh4op(i1111_nnnn_mmmm_1011)
{
	if (fpscr.SZ == 0)
	{
		//iNimp("fmov.s <FREG_M>,@-<REG_N>");
		u32 n = GetN(op);
		u32 m = GetM(op);

		u32 addr = r[n] - 4;

		WriteMemU32(addr, fr_hex[m]);

		r[n] = addr;
	}
	else
	{
		u32 n = GetN(op);
		u32 m = GetM(op)>>1;

		u32 addr = r[n] - 8;
		if (((op >> 4) & 0x1) == 0)
		{
			WriteMemU64(addr, dr_hex[m]);
		}
		else
		{
			WriteMemU64(addr, xd_hex[m]);
		}

		r[n] = addr;
	}
}

//end of memory opcodes

//fmov <FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_1100)
{
	if (fpscr.SZ == 0)
	{
		u32 n = GetN(op);
		u32 m = GetM(op);
		fr[n] = fr[m];
	}
	else
	{
		u32 n = GetN(op)>>1;
		u32 m = GetM(op)>>1;
		switch ((op >> 4) & 0x11)
		{
			case 0x00:
				//dr[n] = dr[m];
				dr_hex[n] = dr_hex[m];
				break;

			case 0x01:
				//dr[n] = xd[m];
				dr_hex[n] = xd_hex[m];
				break;

			case 0x10:
				//xd[n] = dr[m];
				xd_hex[n] = dr_hex[m];
				break;

			case 0x11:
				//xd[n] = xd[m];
				xd_hex[n] = xd_hex[m];
				break;
		}
	}
}


//fabs <FREG_N>
sh4op(i1111_nnnn_0101_1101)
{
	int n=GetN(op);

	if (fpscr.PR ==0)
		fr_hex[n]&=0x7FFFFFFF;
	else
		fr_hex[(n&0xE)]&=0x7FFFFFFF;

}

//FSCA FPUL, DRn//F0FD//1111_nnn0_1111_1101
sh4op(i1111_nnn0_1111_1101)
{
	int n=GetN(op) & 0xE;


	//cosine(x) = sine(pi/2 + x).
	if (fpscr.PR==0)
	{
		u32 pi_index=fpul&0xFFFF;

	#ifdef NATIVE_FSCA
			float rads=pi_index/(65536.0f/2)*pi;

			fr[n + 0] = sinf(rads);
			fr[n + 1] = cosf(rads);

			CHECK_FPU_32(fr[n]);
			CHECK_FPU_32(fr[n+1]);
	#else
			fr[n + 0] = sin_table[pi_index].u[0];
			fr[n + 1] = sin_table[pi_index].u[1];
	#endif

	}
	else
		iNimp("FSCA : Double precision mode");
}

//FSRRA //1111_nnnn_0111_1101
sh4op(i1111_nnnn_0111_1101)
{
	// What about double precision?
	u32 n = GetN(op);
	if (fpscr.PR==0)
	{
		fr[n] = (float)(1/sqrtf(fr[n]));
		CHECK_FPU_32(fr[n]);
	}
	else
		iNimp("FSRRA : Double precision mode");
}

//fcnvds <DR_N>,FPUL
sh4op(i1111_nnnn_1011_1101)
{

	if (fpscr.PR == 1)
	{
		u32 n = (op >> 9) & 0x07;
		u32*p=&fpul;
		*((float*)p) = (float)GetDR(n);
	}
	else
	{
		iNimp("fcnvds <DR_N>,FPUL,m=0");
	}
}


//fcnvsd FPUL,<DR_N>
sh4op(i1111_nnnn_1010_1101)
{
	if (fpscr.PR == 1)
	{
		u32 n = (op >> 9) & 0x07;
		u32* p = &fpul;
		SetDR(n,(double)*((float*)p));
	}
	else
	{
		iNimp("fcnvsd FPUL,<DR_N>,m=0");
	}
}

//fipr <FV_M>,<FV_N>
sh4op(i1111_nnmm_1110_1101)
{
	int n=GetN(op)&0xC;
	int m=(GetN(op)&0x3)<<2;
	if(fpscr.PR ==0)
	{
		float idp;
		idp=fr[n+0]*fr[m+0];
		idp+=fr[n+1]*fr[m+1];
		idp+=fr[n+2]*fr[m+2];
		idp+=fr[n+3]*fr[m+3];

		CHECK_FPU_32(idp);
		fr[n+3]=idp;
	}
	else
	{
		die("FIPR Precision=1");
	}
}

//fldi0 <FREG_N>
sh4op(i1111_nnnn_1000_1101)
{
	if (fpscr.PR!=0)
		die("fldi0 <Dreg_N>");

	u32 n = GetN(op);

	fr[n] = 0.0f;

}

//fldi1 <FREG_N>
sh4op(i1111_nnnn_1001_1101)
{
	if (fpscr.PR!=0)
		die("fldi1 <Dreg_N>");

	u32 n = GetN(op);

	fr[n] = 1.0f;
}

//flds <FREG_N>,FPUL
sh4op(i1111_nnnn_0001_1101)
{
	u32 n = GetN(op);

	fpul = fr_hex[n];
}

//fsts FPUL,<FREG_N>
sh4op(i1111_nnnn_0000_1101)
{
	u32 n = GetN(op);
	fr_hex[n] = fpul;
}

//float FPUL,<FREG_N>
sh4op(i1111_nnnn_0010_1101)
{
	if (fpscr.PR == 0)
	{
		u32 n = GetN(op);
		fr[n] = (float)(int)fpul;
	}
	else
	{
		u32 n = (op >> 9) & 0x07;
		SetDR(n, (double)(int)fpul);
	}
}


//fneg <FREG_N>
sh4op(i1111_nnnn_0100_1101)
{
	u32 n = GetN(op);

	if (fpscr.PR ==0)
		fr_hex[n]^=0x80000000;
	else
		fr_hex[(n&0xE)]^=0x80000000;
}


//frchg
sh4op(i1111_1011_1111_1101)
{
 	fpscr.FR = 1 - fpscr.FR;

	UpdateFPSCR();
}

//fschg
sh4op(i1111_0011_1111_1101)
{
	//iNimp("fschg");
	fpscr.SZ = 1 - fpscr.SZ;
}

//fsqrt <FREG_N>
sh4op(i1111_nnnn_0110_1101)
{
	if (fpscr.PR == 0)
	{
		u32 n = GetN(op);

		fr[n] = sqrtf(fr[n]);
		CHECK_FPU_32(fr[n]);
	}
	else
	{
		//Operation _can_ be done on sh4
		u32 n = GetN(op)>>1;

		SetDR(n,sqrt(GetDR(n)));
	}
}


//ftrc <FREG_N>, FPUL
sh4op(i1111_nnnn_0011_1101)
{
	if (fpscr.PR == 0)
	{
		u32 n = GetN(op);
		fpul = (u32)(s32)min(fr[n], 2147483520.0f);     // IEEE 754: 0x4effffff

		// Intel CPUs convert out of range float numbers to 0x80000000. Manually set the correct sign
		if (fpul == 0x80000000)
		{
			if (*(int *)&fr[n] > 0) // Using integer math to avoid issues with Inf and NaN
				fpul--;
		}
	}
	else
	{
		u32 n = (op >> 9) & 0x07;
		f64 f = GetDR(n);
		fpul = (u32)(s32)f;

		// Intel CPUs convert out of range float numbers to 0x80000000. Manually set the correct sign
		if (fpul == 0x80000000)
		{
			if (*(s64 *)&f > 0)     // Using integer math to avoid issues with Inf and NaN
				fpul--;
		}
	}
}


//fmac <FREG_0>,<FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_1110)
{
	//iNimp("fmac <FREG_0>,<FREG_M>,<FREG_N>");
	if (fpscr.PR==0)
	{
		u32 n = GetN(op);
		u32 m = GetM(op);

		fr[n] =(f32) ((f64)fr[n]+(f64)fr[0] * (f64)fr[m]);
		CHECK_FPU_32(fr[n]);
	}
	else
	{
		iNimp("fmac <DREG_0>,<DREG_M>,<DREG_N>");
	}
}


//ftrv xmtrx,<FV_N>
sh4op(i1111_nn01_1111_1101)
{
	//iNimp("ftrv xmtrx,<FV_N>");

	/*
	XF[0] XF[4] XF[8] XF[12]    FR[n]      FR[n]
	XF[1] XF[5] XF[9] XF[13]  *	FR[n+1] -> FR[n+1]
	XF[2] XF[6] XF[10] XF[14]   FR[n+2]    FR[n+2]
	XF[3] XF[7] XF[11] XF[15]   FR[n+3]    FR[n+3]
	
	gota love linear algebra !
	*/

	u32 n=GetN(op)&0xC;

	if (fpscr.PR==0)
	{

		float v1, v2, v3, v4;

		v1 = xf[0]  * fr[n + 0] +
			 xf[4]  * fr[n + 1] +
			 xf[8]  * fr[n + 2] +
			 xf[12] * fr[n + 3];

		v2 = xf[1]  * fr[n + 0] +
			 xf[5]  * fr[n + 1] +
			 xf[9]  * fr[n + 2] +
			 xf[13] * fr[n + 3];

		v3 = xf[2]  * fr[n + 0] +
			 xf[6]  * fr[n + 1] +
			 xf[10] * fr[n + 2] +
			 xf[14] * fr[n + 3];

		v4 = xf[3]  * fr[n + 0] +
			 xf[7]  * fr[n + 1] +
			 xf[11] * fr[n + 2] +
			 xf[15] * fr[n + 3];

		CHECK_FPU_32(v1);
		CHECK_FPU_32(v2);
		CHECK_FPU_32(v3);
		CHECK_FPU_32(v4);

		fr[n + 0] = v1;
		fr[n + 1] = v2;
		fr[n + 2] = v3;
		fr[n + 3] = v4;

	}
	else
	{
		iNimp("FTRV in dp mode");
	}
}


void iNimp(const char*str)
{
	printf("Unimplemented sh4 FPU instruction: %s\n", str);
	//Sh4_int_Stop();
}
