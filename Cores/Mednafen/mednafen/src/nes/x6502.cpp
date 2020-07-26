/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "nes.h"
#include "x6502.h"
#include "sound.h"
#include "debug.h"

namespace MDFN_IEN_NES
{
X6502 X;

#ifdef WANT_DEBUGGER
void (*X6502_Run)(int32 cycles);
#endif

uint32 timestamp;
void (MDFN_FASTCALL *MapIRQHook)(int a);

#define CPU_PC              X.PC
#define CPU_A               X.A
#define CPU_X               X.X
#define CPU_Y               X.Y
#define CPU_S               X.S
#define CPU_P               X.P
#define CPU_PI              X.mooPI
#define CPU_DB              X.DB
#define CPU_count           X.count
#define CPU_tcount          X.tcount
#define CPU_IRQlow          X.IRQlow
#define CPU_jammed          X.jammed

#define ADDCYC(x)       \
{       \
 int __x=x;     \
 CPU_tcount+=__x;  \
 CPU_count-=__x*48;        \
 timestamp+=__x;        \
}

static INLINE uint8 RdMemNorm(unsigned int A)
{
 return(CPU_DB=ARead[A](A));
}

static INLINE void WrMemNorm(unsigned int A, uint8 V)
{
 BWrite[A](A,V);
}

#ifdef WANT_DEBUGGER
static X6502 XSave;     /* This is getting ugly. */
//#define RdMemHook(A)	( X.ReadHook?(CPU_DB=X.ReadHook(&X,A)):(CPU_DB=ARead[A](A)) )
//#define WrMemHook(A,V)	{ if(X.WriteHook) X.WriteHook(&X,A,V); else BWrite[A](A,V); }

static INLINE uint8 RdMemHook(unsigned int A)
{
 if(X.ReadHook)
  return(CPU_DB = X.ReadHook(&X,A) );
 else
  return(CPU_DB=ARead[A](A));
}
 
static INLINE void WrMemHook(unsigned int A, uint8 V)
{
 if(X.WriteHook)
  X.WriteHook(&X,A,V);
 else if(!X.preexec)
  BWrite[A](A,V);
}
#endif

uint8 X6502_DMR(uint32 A)
{
 ADDCYC(1);
 return(X.DB=ARead[A](A));
}

void X6502_DMW(uint32 A, uint8 V)
{
 ADDCYC(1);
 BWrite[A](A,V);
}

#define PUSH(V) \
{       \
 uint8 VTMP=V;  \
 WrMem(0x100+CPU_S,VTMP);  \
 CPU_S--;  \
}       

#define POP() RdMem(0x100+(++CPU_S))

static uint8 ZNTable[256];
/* Some of these operations will only make sense if you know what the flag
   constants are. */

#define X_ZN(zort)      CPU_P&=~(Z_FLAG|N_FLAG);CPU_P|=ZNTable[zort]
#define X_ZNT(zort)	CPU_P|=ZNTable[zort]

#define JR(cond);	\
{		\
 if(cond)	\
 {	\
  uint32 tmp;	\
  int32 disp;	\
  disp=(int8)RdMem(CPU_PC);	\
  CPU_PC++;	\
  ADDCYC(1);	\
  tmp=CPU_PC;	\
  CPU_PC+=disp;	\
  if((tmp^CPU_PC)&0x100)   \
  ADDCYC(1);    \
		\
  ADDBT(CPU_PC);	\
 }	\
 else CPU_PC++;	\
}

#define ARNOP	   (void)x

#define LDA	   CPU_A=x;X_ZN(CPU_A)
#define LDX	   CPU_X=x;X_ZN(CPU_X)
#define LDY        CPU_Y=x;X_ZN(CPU_Y)

/*  All of the freaky arithmetic operations. */
#define AND        CPU_A&=x;X_ZN(CPU_A)
#define BIT        CPU_P&=~(Z_FLAG|V_FLAG|N_FLAG);CPU_P|=ZNTable[x&CPU_A]&Z_FLAG;CPU_P|=x&(V_FLAG|N_FLAG)
#define EOR        CPU_A^=x;X_ZN(CPU_A)
#define ORA        CPU_A|=x;X_ZN(CPU_A)

#define ADC  {	\
	      uint32 l=CPU_A+x+(CPU_P&1);	\
	      CPU_P&=~(Z_FLAG|C_FLAG|N_FLAG|V_FLAG);	\
              CPU_P|=((((CPU_A^x)&0x80)^0x80) & ((CPU_A^l)&0x80))>>1;	\
              CPU_P|=(l>>8)&C_FLAG;	\
	      CPU_A=l;	\
	      X_ZNT(CPU_A);	\
	     }

#define SBC  {	\
	      uint32 l=CPU_A-x-((CPU_P&1)^1);	\
	      CPU_P&=~(Z_FLAG|C_FLAG|N_FLAG|V_FLAG);	\
	      CPU_P|=((CPU_A^l)&(CPU_A^x)&0x80)>>1;	\
	      CPU_P|=((l>>8)&C_FLAG)^C_FLAG;	\
	      CPU_A=l;	\
	      X_ZNT(CPU_A);	\
	     }

#define CMPL(a1,a2) {	\
		     uint32 t=a1-a2;	\
		     X_ZN(t&0xFF);	\
		     CPU_P&=~C_FLAG;	\
		     CPU_P|=((t>>8)&C_FLAG)^C_FLAG;	\
		    }

/* Special undocumented operation.  Very similar to CMP. */
#define AXS	    {	\
                     uint32 t=(CPU_A&CPU_X)-x;    \
                     X_ZN(t&0xFF);      \
                     CPU_P&=~C_FLAG;       \
                     CPU_P|=((t>>8)&C_FLAG)^C_FLAG;        \
		     CPU_X=t;	\
                    }

#define CMP		CMPL(CPU_A,x)
#define CPX		CMPL(CPU_X,x)
#define CPY	      	CMPL(CPU_Y,x)

/* The following operations modify the byte being worked on. */
#define DEC       	x--;X_ZN(x)
#define INC		x++;X_ZN(x)

#define ASL        CPU_P&=~C_FLAG;CPU_P|=x>>7;x<<=1;X_ZN(x)
#define LSR	CPU_P&=~(C_FLAG|N_FLAG|Z_FLAG);CPU_P|=x&1;x>>=1;X_ZNT(x)

/* For undocumented instructions, maybe for other things later... */
#define LSRA	CPU_P&=~(C_FLAG|N_FLAG|Z_FLAG);CPU_P|=CPU_A&1;CPU_A>>=1;X_ZNT(CPU_A)

#define ROL	{	\
		 uint8 l=x>>7;	\
		 x<<=1;	\
		 x|=CPU_P&C_FLAG;	\
		 CPU_P&=~(Z_FLAG|N_FLAG|C_FLAG);	\
		 CPU_P|=l;	\
		 X_ZNT(x);	\
		}
#define ROR	{	\
		 uint8 l=x&1;	\
		 x>>=1;	\
		 x|=(CPU_P&C_FLAG)<<7;	\
		 CPU_P&=~(Z_FLAG|N_FLAG|C_FLAG);	\
		 CPU_P|=l;	\
		 X_ZNT(x);	\
		}
		 
/* Icky icky thing for some undocumented instructions.  Can easily be
   broken if names of local variables are changed.
*/

/* Absolute */
#define GetAB(target) 	\
{	\
 target=RdMem(CPU_PC);	\
 CPU_PC++;	\
 target|=RdMem(CPU_PC)<<8;	\
 CPU_PC++;	\
}

/* Absolute Indexed(for reads) */
#define GetABIRD(target, i)	\
{	\
 unsigned int tmp;	\
 GetAB(tmp);	\
 target=tmp;	\
 target+=i;	\
 if((target^tmp)&0x100)	\
 {	\
  RdMem(target - 0x100);	\
  ADDCYC(1);	\
 }	\
}

/* Absolute Indexed(for writes and rmws) */
#define GetABIWR(target, i)	\
{	\
 unsigned int rt;	\
 GetAB(rt);	\
 target=rt;	\
 target+=i;	\
 RdMem((target&0x00FF)|(rt&0xFF00));	\
}

/* Zero Page */
#define GetZP(target)	\
{	\
 target=RdMem(CPU_PC); 	\
 CPU_PC++;	\
}

/* Zero Page Indexed */
#define GetZPI(target,i)	\
{	\
 target=i+RdMem(CPU_PC);	\
 CPU_PC++;	\
}

/* Indexed Indirect */
#define GetIX(target)	\
{	\
 uint8 tmp;	\
 tmp=RdMem(CPU_PC);	\
 CPU_PC++;	\
 tmp+=CPU_X;	\
 target=RdMem(tmp);	\
 tmp++;		\
 target|=RdMem(tmp)<<8;	\
}

/* Indirect Indexed(for reads) */
#define GetIYRD(target)	\
{	\
 unsigned int rt;	\
 uint8 tmp;	\
 tmp=RdMem(CPU_PC);	\
 CPU_PC++;	\
 rt=RdMem(tmp);	\
 tmp++;	\
 rt|=RdMem(tmp)<<8;	\
 target=rt;	\
 target+=CPU_Y;	\
 if((target^rt)&0x100)	\
 {	\
  RdMem(target - 0x100);	\
  ADDCYC(1);	\
 }	\
}

/* Indirect Indexed(for writes and rmws) */
#define GetIYWR(target)	\
{	\
 unsigned int rt;	\
 uint8 tmp;	\
 tmp=RdMem(CPU_PC);	\
 CPU_PC++;	\
 rt=RdMem(tmp);	\
 tmp++;	\
 rt|=RdMem(tmp)<<8;	\
 target=rt;	\
 target+=CPU_Y;	\
 RdMem((target&0x00FF)|(rt&0xFF00));	\
}

/* Now come the macros to wrap up all of the above stuff addressing mode functions
   and operation macros.  Note that operation macros will always operate(redundant
   redundant) on the variable "x".
*/

#define RMW_A(op) {uint8 x=CPU_A; op; CPU_A=x; break; } /* Meh... */
#define RMW_AB(op) {unsigned int A; uint8 x; GetAB(A); x=RdMem(A); WrMem(A,x); op; WrMem(A,x); break; }
#define RMW_ABI(reg,op) {unsigned int A; uint8 x; GetABIWR(A,reg); x=RdMem(A); WrMem(A,x); op; WrMem(A,x); break; }
#define RMW_ABX(op)	RMW_ABI(CPU_X,op)
#define RMW_ABY(op)	RMW_ABI(CPU_Y,op)
#define RMW_IX(op)  {unsigned int A; uint8 x; GetIX(A); x=RdMem(A); WrMem(A,x); op; WrMem(A,x); break; }
#define RMW_IY(op)  {unsigned int A; uint8 x; GetIYWR(A); x=RdMem(A); WrMem(A,x); op; WrMem(A,x); break; }
#define RMW_ZP(op)  {uint8 A; uint8 x; GetZP(A); x=RdMem(A); op; WrMem(A,x); break; }
#define RMW_ZPX(op) {uint8 A; uint8 x; GetZPI(A,CPU_X); x=RdMem(A); op; WrMem(A,x); break;}

#define LD_IM(op)	{uint8 x; x=RdMem(CPU_PC); CPU_PC++; op; break;}
#define LD_ZP(op)	{uint8 A; uint8 x; GetZP(A); x=RdMem(A); op; break;}
#define LD_ZPX(op)  {uint8 A; uint8 x; GetZPI(A,CPU_X); x=RdMem(A); op; break;}
#define LD_ZPY(op)  {uint8 A; uint8 x; GetZPI(A,CPU_Y); x=RdMem(A); op; break;}
#define LD_AB(op)	{unsigned int A; uint8 x; GetAB(A); x=RdMem(A); op; break; }
#define LD_ABI(reg,op)  {unsigned int A; uint8 x; GetABIRD(A,reg); x=RdMem(A); op; break;}
#define LD_ABX(op)	LD_ABI(CPU_X,op)
#define LD_ABY(op)	LD_ABI(CPU_Y,op)
#define LD_IX(op)	{unsigned int A; uint8 x; GetIX(A); x=RdMem(A); op; break;}
#define LD_IY(op)	{unsigned int A; uint8 x; GetIYRD(A); x=RdMem(A); op; break;}

#define ST_ZP(r)	{uint8 A; GetZP(A); WrMem(A,r); break;}
#define ST_ZPX(r)	{uint8 A; GetZPI(A,CPU_X); WrMem(A,r); break;}
#define ST_ZPY(r)	{uint8 A; GetZPI(A,CPU_Y); WrMem(A,r); break;}
#define ST_AB(r)	{unsigned int A; GetAB(A); WrMem(A,r); break;}
#define ST_ABI(reg,r)	{unsigned int A; GetABIWR(A,reg); WrMem(A,r); break; }
#define ST_ABX(r)	ST_ABI(CPU_X,r)
#define ST_ABY(r)	ST_ABI(CPU_Y,r)
#define ST_IX(r)	{unsigned int A; GetIX(A); WrMem(A,r); break; }
#define ST_IY(r)	{unsigned int A; GetIYWR(A); WrMem(A,r); break; }

static const uint8 CycTable[256] =
{                             
/*0x00*/ 7,6,2,8,3,3,5,5,3,2,2,2,4,4,6,6,
/*0x10*/ 2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,
/*0x20*/ 6,6,2,8,3,3,5,5,4,2,2,2,4,4,6,6,
/*0x30*/ 2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,
/*0x40*/ 6,6,2,8,3,3,5,5,3,2,2,2,3,4,6,6,
/*0x50*/ 2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,
/*0x60*/ 6,6,2,8,3,3,5,5,4,2,2,2,5,4,6,6,
/*0x70*/ 2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,
/*0x80*/ 2,6,2,6,3,3,3,3,2,2,2,2,4,4,4,4,
/*0x90*/ 2,6,2,6,4,4,4,4,2,5,2,5,5,5,5,5,
/*0xA0*/ 2,6,2,6,3,3,3,3,2,2,2,2,4,4,4,4,
/*0xB0*/ 2,5,2,5,4,4,4,4,2,4,2,4,4,4,4,4,
/*0xC0*/ 2,6,2,8,3,3,5,5,2,2,2,2,4,4,6,6,
/*0xD0*/ 2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,
/*0xE0*/ 2,6,2,8,3,3,5,5,2,2,2,2,4,4,6,6,
/*0xF0*/ 2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,
};

void X6502_IRQBegin(int w)
{
 //printf("IRQ begin: %d; %d\n", w, CPU_IRQlow);
 CPU_IRQlow|=w;
}

void X6502_IRQEnd(int w)
{
 //printf("IRQ end: %d; %d\n", w, CPU_IRQlow);
 CPU_IRQlow&=~w;
}

void TriggerNMI(void)
{
 CPU_IRQlow|=MDFN_IQNMI;
}

void TriggerNMI2(void)
{ 
 CPU_IRQlow|=MDFN_IQNMI2;
}

/* Called from debugger. */
void MDFNI_NMI(void)
{
 CPU_IRQlow|=MDFN_IQNMI;
}

void MDFNI_IRQ(void)
{
 CPU_IRQlow|=MDFN_IQTEMP;
}

void X6502_GetIVectors(uint16 *reset, uint16 *irq, uint16 *nmi)
{
 fceuindbg=1;

 *reset=RdMemNorm(0xFFFC);
 *reset|=RdMemNorm(0xFFFD)<<8;
 *nmi=RdMemNorm(0xFFFA);
 *nmi|=RdMemNorm(0xFFFB)<<8;
 *irq=RdMemNorm(0xFFFE);
 *irq|=RdMemNorm(0xFFFF)<<8;
 fceuindbg=0;
}
static int debugmode;

void X6502_Reset(void)
{
 CPU_IRQlow=MDFN_IQRESET;
}
  
void X6502_Init(void)
{
	int x;

	memset((void *)&X,0,sizeof(X));
	for(x=0;x<256;x++)
	 if(!x) ZNTable[x]=Z_FLAG;
	 else if (x&0x80) ZNTable[x]=N_FLAG;
	 else ZNTable[x]=0;
	#ifdef WANT_DEBUGGER
	X6502_Debug(0,0,0);
	#endif
}

void X6502_Power(void)
{
 CPU_count=CPU_tcount=CPU_IRQlow=CPU_PC=CPU_A=CPU_X=CPU_Y=CPU_S=CPU_P=CPU_PI=CPU_DB=CPU_jammed=0;
 timestamp=0;
 X6502_Reset();
}

#ifdef WANT_DEBUGGER
static void X6502_RunDebug(int32 cycles)
{
	#define RdMem RdMemHook
	#define WrMem WrMemHook
        #define ADDBT(to) NESDBG_AddBranchTrace(oldCPU_PC, to, 0)

        if(PAL)
         cycles*=15;          // 15*4=60
        else
         cycles*=16;          // 16*4=64

        CPU_count+=cycles;

	PenguinPower:
        while(CPU_count>0)
        {
	 const uint16 oldCPU_PC = CPU_PC;
         int32 temp;
         uint8 b1;

         if(CPU_IRQlow && !X.cpoint) // Don't run IRQ stuff if we weren't here in a save state
         { 
          if(CPU_IRQlow&MDFN_IQRESET)
          {
	   CPU_S -= 3;
           CPU_PC=RdMem(0xFFFC);
           CPU_PC|=RdMem(0xFFFD)<<8;
	   NESDBG_AddBranchTrace(oldCPU_PC, CPU_PC, 0xFFFC); //	   ADDBT(CPU_PC);
           CPU_jammed=0;
           CPU_PI=CPU_P=I_FLAG;
           CPU_IRQlow&=~MDFN_IQRESET;
          }
          else if(CPU_IRQlow&MDFN_IQNMI2)
          {
           CPU_IRQlow&=~MDFN_IQNMI2; 
           CPU_IRQlow|=MDFN_IQNMI;
          }
          else if(CPU_IRQlow&MDFN_IQNMI)
          {
           if(!CPU_jammed)
           {
            ADDCYC(7);
            PUSH(CPU_PC>>8);
            PUSH(CPU_PC);
            PUSH((CPU_P&~B_FLAG)|(U_FLAG));
            CPU_P|=I_FLAG; 
            CPU_PC=RdMem(0xFFFA); 
            CPU_PC|=RdMem(0xFFFB)<<8;
	    NESDBG_AddBranchTrace(oldCPU_PC, CPU_PC, 0xFFFA); //    ADDBT(CPU_PC);
            CPU_IRQlow&=~MDFN_IQNMI;
           }
          }
          else 
          { 
           if(!(CPU_PI&I_FLAG) && !CPU_jammed)
           {
            ADDCYC(7);
            PUSH(CPU_PC>>8);
            PUSH(CPU_PC);
            PUSH((CPU_P&~B_FLAG)|(U_FLAG));
            CPU_P|=I_FLAG;
            CPU_PC=RdMem(0xFFFE);
            CPU_PC|=RdMem(0xFFFF)<<8;
	    NESDBG_AddBranchTrace(oldCPU_PC, CPU_PC, 0xFFFE);	//ADDBT(CPU_PC);
           }
          }
          CPU_IRQlow&=~(MDFN_IQTEMP);
          if(CPU_count<=0) 
          {
           CPU_PI=CPU_P;
           return;
          } /* Should increase accuracy without a */
             /* major speed hit. */
         }

	 /* Ok, now the real fun starts. */
	 /* Do the pre-exec voodoo. */

         if(X.ReadHook || X.WriteHook)
	 {
	  uint32 tsave=timestamp;
          XSave=X;

	  fceuindbg=1;
	  X.preexec=1;
          b1=RdMem(CPU_PC);
          CPU_PC++;
          switch(b1)
          {   
           #include "ops.h"
          }  

	  timestamp=tsave;

	  X=XSave;
	  fceuindbg=0;
	 }

	 X.cpoint = 1;

	 if(X.CPUHook) X.CPUHook(CPU_PC);
	 if(!X.cpoint)
	  goto PenguinPower;
	 X.cpoint = 0;

         CPU_PI = CPU_P;
         b1=RdMem(CPU_PC);
         ADDCYC(CycTable[b1]);

         temp=CPU_tcount;
         CPU_tcount=0;
         if(MapIRQHook) MapIRQHook(temp);

	 MDFN_SoundCPUHook(temp);

         CPU_PC++;
         switch(b1)
         {
          #include "ops.h"
         } 
         CPU_PC &= 0xFFFF;
        }
        #undef RdMem
        #undef WrMem
	#undef ADDBT
}

static void X6502_RunNormal(int32 cycles)
{
#else
void X6502_Run(int32 cycles)
{
#endif
	#define RdMem RdMemNorm
	#define WrMem WrMemNorm
        #define ADDBT(x)

        uint32 pbackus;

        pbackus=CPU_PC;

        #undef CPU_PC
        #define CPU_PC pbackus

	if(PAL)
	 cycles*=15;          // 15*4=60
	else
	 cycles*=16;          // 16*4=64

	CPU_count+=cycles;
	
        // This handles the (rare) case of a save state being saved in step mode in the debugger
        if(X.cpoint && CPU_count > 0)
        {
         X.cpoint = 0;
         goto SephirothBishie;
        }

	while(CPU_count>0)
	{
	 int32 temp;
	 static uint8 b1;

	 if(CPU_IRQlow)
	 {
	  if(CPU_IRQlow&MDFN_IQRESET)
	  {
	   CPU_S -= 3;
	   CPU_PC=RdMem(0xFFFC);
	   CPU_PC|=RdMem(0xFFFD)<<8;
	   CPU_jammed=0;
	   CPU_PI=CPU_P=I_FLAG;
	   CPU_IRQlow&=~MDFN_IQRESET;
	  }
	  else if(CPU_IRQlow&MDFN_IQNMI2)
 	  {
	   CPU_IRQlow&=~MDFN_IQNMI2; 
	   CPU_IRQlow|=MDFN_IQNMI;
	  }
	  else if(CPU_IRQlow&MDFN_IQNMI)
	  {
	   if(!CPU_jammed)
	   {
	    ADDCYC(7);
	    PUSH(CPU_PC>>8);
	    PUSH(CPU_PC);
	    PUSH((CPU_P&~B_FLAG)|(U_FLAG));
	    CPU_P|=I_FLAG;		
	    CPU_PC=RdMem(0xFFFA); 
	    CPU_PC|=RdMem(0xFFFB)<<8;
	    CPU_IRQlow&=~MDFN_IQNMI;
	   }
	  }
	  else
	  { 
	   if(!(CPU_PI&I_FLAG) && !CPU_jammed)
	   {
	    ADDCYC(7);
	    PUSH(CPU_PC>>8);
	    PUSH(CPU_PC);
	    PUSH((CPU_P&~B_FLAG)|(U_FLAG));
	    CPU_P|=I_FLAG;
	    CPU_PC=RdMem(0xFFFE);
	    CPU_PC|=RdMem(0xFFFF)<<8;
	   }
	  }
	  CPU_IRQlow&=~(MDFN_IQTEMP);
	  if(CPU_count<=0) 
	  {
	   CPU_PI=CPU_P;
	   X.PC = pbackus;
	   return;
	   } /* Should increase accuracy without a  major speed hit. */
	 }

 	 SephirothBishie:

	 CPU_PI = CPU_P;
	 b1=RdMem(CPU_PC);

	 ADDCYC(CycTable[b1]);

	 temp=CPU_tcount;
	 CPU_tcount=0;
	 if(MapIRQHook) MapIRQHook(temp);
	 MDFN_SoundCPUHook(temp);
	 CPU_PC++;

         switch(b1)
         {
          #include "ops.h"
         } 
         CPU_PC &= 0xFFFF;
	}

        #undef CPU_PC
        #define CPU_PC X.PC
	#undef ADDBT
        CPU_PC=pbackus;
}

void X6502_StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 MDFN_HIDE extern uint8 RAM[0x800]; // from nes.cpp

 SFORMAT SFCPU[]={
  SFVARN(X.PC, "PC"),
  SFVARN(X.A, "A"),
  SFVARN(X.P, "P"),
  SFVARN(X.mooPI, "PI"),
  SFVARN(X.X, "X"),
  SFVARN(X.Y, "Y"),
  SFVARN(X.S, "S"),
  SFPTR8N(RAM, 0x800, "RAM"),
  SFEND
 };

 SFORMAT SFCPUC[]={
  SFVARN(X.jammed, "jammed"),
  SFVARN(X.IRQlow, "IRQLow"),
  SFVARN(X.tcount, "tcount"),
  SFVARN(X.count, "count"),
  SFVARN(timestampbase, "timestampbase"),
  SFVARN(X.cpoint, "CPoint"),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, SFCPU, "CPU");
 MDFNSS_StateAction(sm, load, data_only, SFCPUC, "CPUC");

 if(load)
 {
  X.PC &= 0xFFFF;

  // (312 - 242) * 341 * 15
  // 27384...
  if(X.count > 524288)
   X.count = 524288;
  else if(X.count < -5000 * 16)
   X.count = -5000 * 16;

  // RMW, $4014 512 * 2...8...DMC too...
  if(X.tcount > 5000)
   X.tcount = 5000;
  else if(X.tcount < 0)
   X.tcount = 0;

  //printf("%d %d\n", X.count, X.tcount);
 }
}

#ifdef WANT_DEBUGGER
void X6502_Debug(void (*CPUHook)(uint32),
		uint8 (*ReadHook)(X6502 *, unsigned int),
		void (*WriteHook)(X6502 *, unsigned int, uint8))
{
 debugmode=(ReadHook || WriteHook || CPUHook)?1:0;
 X.ReadHook=ReadHook;
 X.WriteHook=WriteHook;
 X.CPUHook=CPUHook;

 if(!debugmode)
  X6502_Run=X6502_RunNormal;
 else
  X6502_Run=X6502_RunDebug;
}
#endif

}
