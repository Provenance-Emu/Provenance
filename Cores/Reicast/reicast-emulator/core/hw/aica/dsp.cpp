#include "dsp.h"
#include "aica_mem.h"
#include "hw/aica/aica_if.h"
#include "oslib/oslib.h"

/*
	DSP rec_v1

	Tries to emulate a guesstimation of the aica dsp, by directly emitting x86 opcodes.

	This was my first dsp implementation, as implemented for nullDC 1.0.3. 
	
	This was derived from a schematic I drew for the dsp, based on 
	liberal interpretation of known specs, the saturn dsp, digital 
	electronics assumptions, as well as "best-fitted" my typical 
	test game suite.


	Initiall code by skmp, now part of the reicast project.
	See LICENSE & COPYRIGHT files further details
*/

DECL_ALIGN(4096) dsp_t dsp;

#if HOST_CPU == CPU_X86 && FEAT_DSPREC == DYNAREC_JIT
#include "emitter/x86_emitter.h"

const bool SUPPORT_NOFL=false;


#define assert verify

#pragma warning(disable:4311)

struct _INST
{
	unsigned int TRA;
	unsigned int TWT;
	unsigned int TWA;
	
	unsigned int XSEL;
	unsigned int YSEL;
	unsigned int IRA;
	unsigned int IWT;
	unsigned int IWA;

	unsigned int EWT;
	unsigned int EWA;
	unsigned int ADRL;
	unsigned int FRCL;
	unsigned int SHIFT;
	unsigned int YRL;
	unsigned int NEGB;
	unsigned int ZERO;
	unsigned int BSEL;

	unsigned int NOFL;  //MRQ set
	unsigned int TABLE; //MRQ set
	unsigned int MWT;   //MRQ set
	unsigned int MRD;   //MRQ set
	unsigned int MASA;  //MRQ set
	unsigned int ADREB; //MRQ set
	unsigned int NXADR; //MRQ set
};


#define DYNBUF  0x10000
/*
//#define USEFLOATPACK
//pack s24 to s1e4s11
naked u16 packasm(s32 val)
{
	__asm
	{
		mov edx,ecx;        //eax will be sign
		and edx,0x80000;    //get the sign
		
		jz poz;
		neg ecx;

		poz:
		bsr eax,ecx;
		jz _zero;

		//24 -> 11
		//13 -> 0
		//12..0 -> 0
		sub eax,11;
		cmovs eax,0;    //if <0 -> 0

		shr ecx,eax;    //shift out mantissa as needed (yeah i know, no rounding here and all .. )

		shr eax,12;     //[14:12] is exp
		or edx,ecx;     //merge [15] | [11:0]
		or eax,edx;     //merge [14:12] | ([15] | [11:0]), result on eax
		ret;

_zero:
		xor eax,eax;
		ret;
	}
}
//ONLY lower 16 bits are valid, rest are ignored but do movzx to avoid partial stalls :)
naked s32 unpackasm(u32 val)
{
	__asm
	{
		mov eax,ecx;        //get mantissa bits
		and ecx,0x7FF;      //
		
		shl eax,11;         //get shift factor (shift)
		mov edx,eax;        //keep a copy for the sign
		and eax,0xF;        //get shift factor (mask)

		shl ecx,eax;        //shift mantissa to normal position

		test edx,0x10;      //signed ?
		jnz _negme;
		
		ret;    //nop, return as is

_negme:
		//yep, negate and return
		neg eax;
		ret;

	}
}*/

//float format is ?
static u16 DYNACALL PACK(s32 val)
{
	u32 temp;
	int sign,exponent,k;

	sign = (val >> 23) & 0x1;
	temp = (val ^ (val << 1)) & 0xFFFFFF;
	exponent = 0;
	for (k=0; k<12; k++)
	{
		if (temp & 0x800000)
			break;
		temp <<= 1;
		exponent += 1;
	}
	if (exponent < 12)
		val = (val << exponent) & 0x3FFFFF;
	else
		val <<= 11;
	val >>= 11;
	val |= sign << 15;
	val |= exponent << 11;

	return (u16)val;
}

static s32 DYNACALL UNPACK(u16 val)
{
	int sign,exponent,mantissa;
	s32 uval;

	sign = (val >> 15) & 0x1;
	exponent = (val >> 11) & 0xF;
	mantissa = val & 0x7FF;
	uval = mantissa << 11;
	if (exponent > 11)
		exponent = 11;
	else
		uval |= (sign ^ 1) << 22;
	uval |= sign << 23;
	uval <<= 8;
	uval >>= 8;
	uval >>= exponent;

	return uval;
}


void dsp_init()
{
	memset(&dsp,0,sizeof(dsp));
	memset(DSPData,0,sizeof(*DSPData));

	dsp.dyndirty=true;
	dsp.RBL=0x2000-1;
	dsp.RBP=0;
	dsp.regs.MDEC_CT=1;


	os_MakeExecutable(dsp.DynCode,sizeof(dsp.DynCode));
}
void dsp_recompile();
void DecodeInst(u32 *IPtr,_INST *i)
{
	i->TRA=(IPtr[0]>>9)&0x7F;
	i->TWT=(IPtr[0]>>8)&0x01;
	i->TWA=(IPtr[0]>>1)&0x7F;
	
	i->XSEL=(IPtr[1]>>15)&0x01;
	i->YSEL=(IPtr[1]>>13)&0x03;
	i->IRA=(IPtr[1]>>7)&0x3F;
	i->IWT=(IPtr[1]>>6)&0x01;
	i->IWA=(IPtr[1]>>1)&0x1F;

	i->TABLE=(IPtr[2]>>15)&0x01;
	i->MWT=(IPtr[2]>>14)&0x01;
	i->MRD=(IPtr[2]>>13)&0x01;
	i->EWT=(IPtr[2]>>12)&0x01;
	i->EWA=(IPtr[2]>>8)&0x0F;
	i->ADRL=(IPtr[2]>>7)&0x01;
	i->FRCL=(IPtr[2]>>6)&0x01;
	i->SHIFT=(IPtr[2]>>4)&0x03;
	i->YRL=(IPtr[2]>>3)&0x01;
	i->NEGB=(IPtr[2]>>2)&0x01;
	i->ZERO=(IPtr[2]>>1)&0x01;
	i->BSEL=(IPtr[2]>>0)&0x01;

	i->NOFL=(IPtr[3]>>15)&1;		//????
	//i->COEF=(IPtr[3]>>9)&0x3f;
	
	i->MASA=(IPtr[3]>>9)&0x3f;	//???
	i->ADREB=(IPtr[3]>>8)&0x1;
	i->NXADR=(IPtr[3]>>7)&0x1;
}


void* dyna_realloc(void*ptr,u32 oldsize,u32 newsize)
{
	return dsp.DynCode;
}
void _dsp_debug_step_start()
{
	memset(&dsp.regs_init,0,sizeof(dsp.regs_init));
}
void _dsp_debug_step_end()
{
	verify(dsp.regs_init.MAD_OUT);
	verify(dsp.regs_init.MEM_ADDR);
	verify(dsp.regs_init.MEM_RD_DATA);
	verify(dsp.regs_init.MEM_WT_DATA);
	verify(dsp.regs_init.FRC_REG);
	verify(dsp.regs_init.ADRS_REG);
	verify(dsp.regs_init.Y_REG);

	//verify(dsp.regs_init.MDEC_CT); // -> its done on C
	verify(dsp.regs_init.MWT_1);
	verify(dsp.regs_init.MRD_1);
//	verify(dsp.regs_init.MADRS); //THAT WAS not real, MEM_ADDR is the deal ;p
	verify(dsp.regs_init.MEMS);
	verify(dsp.regs_init.NOFL_1);
	verify(dsp.regs_init.NOFL_2);
	verify(dsp.regs_init.TEMPS);
	verify(dsp.regs_init.EFREG);
}
#define nwtn(x) verify(!dsp.regs_init.##x)
#define wtn(x) nwtn(x);dsp.regs_init.##x=true;

//sign extend to 32 bits
void dsp_rec_se(x86_block& x86e,x86_gpr_reg reg,u32 src_sz,u32 dst_sz=0xFF)
{
	if (dst_sz==0xFF)
		dst_sz=src_sz;
	//24 -> 32 (pad to 32 bits)
	x86e.Emit(op_shl32,reg,32-src_sz);
	//32 -> 24 (MSB propagation)
	x86e.Emit(op_sar32,reg,32-dst_sz);
}
//Reads : MWT_1,MRD_1,MEM_ADDR
//Writes : Wire MEM_RD_DATA_NV
void dsp_rec_DRAM_CI(x86_block& x86e,_INST& prev_op,u32 step,x86_gpr_reg MEM_RD_DATA_NV)
{
	nwtn(MWT_1);
	nwtn(MRD_1);
	nwtn(MEM_ADDR);
	nwtn(MEM_WT_DATA);

	//Request : step x (odd step)
	//Operation : x+1   (even step)
	//Data avail : x+2   (odd step, can request again)
	if (!(step&1))	
	{
		//Get and mask ram address :)
		x86e.Emit(op_mov32,EAX,&dsp.regs.MEM_ADDR);
		x86e.Emit(op_and32,EAX,AICA_RAM_MASK);

		x86e.Emit(op_add32,EAX,(unat)aica_ram.data);

		//prev. opcode did a mem read request ?
		if (prev_op.MRD)
		{
			//Do the read [MEM_ADDRS] -> MEM_RD_DATA_NV
			x86e.Emit(op_movsx16to32,MEM_RD_DATA_NV,x86_mrm(EAX));
		}
		//prev. opcode did a mem write request ?
		if (prev_op.MWT)
		{
			//Do the write [MEM_ADDRS] <-MEM_WT_DATA
			x86e.Emit(op_mov32,EDX,&dsp.regs.MEM_WT_DATA);
			x86e.Emit(op_mov16,x86_mrm(EAX),EDX);
		}
	}
}
//Reads : ADRS_REG,MADRS,MDEC_CT
//Writes : MEM_ADDR
void dsp_rec_MEM_AGU(x86_block& x86e,_INST& op,u32 step)
{
	nwtn(ADRS_REG);
	nwtn(MEM_ADDR);
	
	//These opcode fields are valid on odd steps (mem req. is only allowed then)
	//MEM Request : step x
	//Mem operation : step x+1 (address is available at this point)
	if (step&1)
	{
		//Addrs is 16:1
		x86e.Emit(op_mov32,EAX,&DSPData->MADRS[op.MASA]);

		//Added if ADREB
		if (op.ADREB)
			x86e.Emit(op_add32,EAX,&dsp.regs.ADRS_REG);
		
		//+1 if NXADR is set
		if (op.NXADR)
			x86e.Emit(op_add32,EAX,1);

		//RBL warp around is here, according to docs, but that seems to cause _very_ bad results
	//	if (!op.TABLE)
	//		x86e.Emit(op_and32,EAX,dsp.RBL);

		//MDEC_CT is added if !TABLE
		if (!op.TABLE)
			x86e.Emit(op_add32,EAX,&dsp.regs.MDEC_CT);

		//RBL/RBP are constants for the program
		//Apply RBL if !TABLE
		//Else limit to 16 bit add
		//*update* always limit to 16 bit add adter MDEC_CT ?
		if (!op.TABLE)
			x86e.Emit(op_and32,EAX,dsp.RBL);
		else
			x86e.Emit(op_and32,EAX,0xFFFF);

		//Calculate the value !
		//EAX*2 b/c it points to sample (16:1 of the address)
		x86e.Emit(op_lea32,EDX,x86_mrm(EAX,sib_scale_2,x86_ptr::create(dsp.RBP)));

		//Save the result to MEM_ADDR
		x86e.Emit(op_mov32,&dsp.regs.MEM_ADDR,EDX);
	}
	wtn(MEM_ADDR);
}
//Reads : MEMS,MIXS,EXTS
//Writes : INPUTS (Wire)
void dsp_rec_INPUTS(x86_block& x86e,_INST& op,x86_gpr_reg INPUTS)
{
	nwtn(MEMS);

	//nwtn(MIXS); -> these are read only :)
	//nwtn(EXTS);

	//INPUTS is 24 bit, we convert everything to that
	//Maby we dont need to convert, but just to sign extend ?
	if(op.IRA<0x20)
	{
		x86e.Emit(op_mov32,INPUTS,&dsp.MEMS[op.IRA]);
		dsp_rec_se(x86e,INPUTS,24);
	}
	else if(op.IRA<0x30)
	{
		x86e.Emit(op_mov32,INPUTS,&dsp.MIXS[op.IRA-0x20]);
		dsp_rec_se(x86e,INPUTS,20,24);
	}
	else if(op.IRA<0x32)
	{
		x86e.Emit(op_mov32,ESI,&DSPData->EXTS[op.IRA-0x30]);
		//x86e.Emit(op_shl32,INPUTS,8);
		dsp_rec_se(x86e,INPUTS,16,24);
	}

	//Sign extend to 32 bits
	//dsp_rec_se(x86e,INPUTS,24);
}
//Reads : MEM_RD_DATA,NO_FLT2
//Writes : MEMS
void dsp_rec_MEMS_WRITE(x86_block& x86e,_INST& op,u32 step,x86_gpr_reg INPUTS)
{
	nwtn(MEM_RD_DATA);
	nwtn(NOFL_2);

	//MEMS write reads from MEM_RD_DATA register (MEM_RD_DATA -> Converter -> MEMS).
	//The converter's nofl flag has 2 steps delay (so that it can be set with the MRQ).
	if (op.IWT)
	{
		x86e.Emit(op_movsx16to32,ECX,&dsp.regs.MEM_RD_DATA);
		x86e.Emit(op_mov32,EAX,ECX);

		//Pad and signed extend EAX
		//x86e.Emit(op_shl32,EAX,16);
		//x86e.Emit(op_sar32,EAX,8);
		x86e.Emit(op_shl32,EAX,8);

		if (SUPPORT_NOFL)
		{
			x86_Label* no_fl=x86e.CreateLabel(false,8);//no float conversions

			//Do we have to convert ?
			x86e.Emit(op_cmp32,&dsp.regs.NOFL_2,1);
			x86e.Emit(op_je,no_fl);
			{
				//Convert !
				x86e.Emit(op_call,x86_ptr_imm(UNPACK));
			}
			x86e.MarkLabel(no_fl);
		}
		x86e.Emit(op_mov32,&dsp.MEMS[op.IWA],EAX);
	}
	
	wtn(MEMS);
}
//Reads : MEM_RD_DATA_NV (Wire)
//Writes : MEM_RD_DATA
void dsp_rec_MEM_RD_DATA_WRITE(x86_block& x86e,_INST& op,u32 step,x86_gpr_reg MEM_RD_DATA_NV)
{
	//Request : step x (odd step)
	//Operation : x+1   (even step)
	//Data avail : x+2   (odd step, can request again)
	//The MEM_RD_DATA_NV wire exists only on even steps
	if (!(step&1))
	{
		x86e.Emit(op_mov32,&dsp.regs.MEM_RD_DATA,MEM_RD_DATA_NV);
	}

	wtn(MEM_RD_DATA);
}

x86_mrm_t dsp_reg_GenerateTempsAddrs(x86_block& x86e,u32 TEMPS_NUM,x86_gpr_reg TEMPSaddrsreg)
{
	x86e.Emit(op_mov32,TEMPSaddrsreg,&dsp.regs.MDEC_CT);
	x86e.Emit(op_add32,TEMPSaddrsreg,TEMPS_NUM);
	x86e.Emit(op_and32,TEMPSaddrsreg,127);
	return x86_mrm(ECX,sib_scale_4,dsp.TEMP);
}
//Reads : INPUTS,TEMP,FRC_REG,COEF,Y_REG
//Writes : MAD_OUT_NV (Wire)
void dsp_rec_MAD(x86_block& x86e,_INST& op,u32 step,x86_gpr_reg INPUTS,x86_gpr_reg MAD_OUT_NV)
{
	bool use_TEMP=op.XSEL==0 || (op.BSEL==0 && op.ZERO==0);

	//TEMPS (if used) on ECX
	const x86_gpr_reg TEMPS_reg=ECX;
	if (use_TEMP)
	{
		//read temps
		x86e.Emit(op_mov32,TEMPS_reg,dsp_reg_GenerateTempsAddrs(x86e,op.TRA,TEMPS_reg));
		dsp_rec_se(x86e,TEMPS_reg,24);
	}

	x86_reg mul_x_input;
	//X : 24 bits
	if (op.XSEL==1)
	{
		//X=INPUTS
		mul_x_input=INPUTS;
		//x86e.Emit(op_mov32,EDX,INPUTS);
	}
	else
	{
		//X=TEMPS
		mul_x_input=TEMPS_reg;
		//x86e.Emit(op_mov32,EDX,TEMPS_reg);
	}

	//MUL Y in : EAX
	//Y : 13 bits
	switch(op.YSEL)
	{
	case 0:
		//Y=FRC_REG[13]
		x86e.Emit(op_mov32,EAX,&dsp.regs.FRC_REG);
		dsp_rec_se(x86e,EAX,13);
		break;

	case 1:
		//Y=COEF[13]
		x86e.Emit(op_mov32,EAX,&DSPData->COEF[step]);
		dsp_rec_se(x86e,EAX,16,13);
		break;

	case 2:
		//Y=Y_REG[23:11] (Y_REG is 19 bits, INPUTS[23:4], so that is realy 19:7)
		x86e.Emit(op_mov32,EAX,&dsp.regs.Y_REG);
		dsp_rec_se(x86e,EAX,19,13);
		break;

	case 3:
		//Y=0'Y_REG[15:4] (Y_REG is 19 bits, INPUTS[23:4], so that is realy 11:0)
		x86e.Emit(op_mov32,EAX,&dsp.regs.Y_REG);
		x86e.Emit(op_and32,0xFFF);//Clear bit 13+
		break;
	}

	//Do the mul -- maby it has overflow protection ?
	//24+13=37, -11 = 26
	//that can be >>1 or >>2 on the shifter after the mul 
	x86e.Emit(op_imul32,mul_x_input);
	//*NOTE* here, shrd is unsigned, but we have EDX signed, and we may only shift up to 11 bits from it
	//so it works just fine :)
	x86e.Emit(op_shrd32,EAX,EDX,10);

	//cut the upper bits so that it is 26 bits signed
	dsp_rec_se(x86e,EAX,26);

	//Adder, takes MUL_OUT at EAX
	//Adds B (EDX)
	//Outputs EAX

	if (!op.ZERO)	//if zero is set the adder has no effect
	{
		if (op.BSEL==1)
		{
			//B=MAD_OUT[??]
			//mad out is stored on s32 format, so no need for sign extension
			x86e.Emit(op_mov32,EDX,&dsp.regs.MAD_OUT);
		}
		else
		{
			//B=TEMP[??]
			//TEMPS is already sign extended, so no need for it
			//Just converting 24 -> 26 bits using lea
			x86e.Emit(op_lea32,EDX,x86_mrm(TEMPS_reg,sib_scale_4,0));
		}
		//Gating is applied here normally (ZERO).
		//NEGB then inverts the value  (NOT) (or 0 , if gated) and the adder adds +1 if NEGB is set.
		//However, (~X)+1 = -X , and (~0)+1=0 so i skip the add
		if (op.NEGB)
		{
			x86e.Emit(op_neg32,EDX);
		}
		
		//Add hm, is there overflow protection here ?
		//The result of mul is on EAX, we modify that
		x86e.Emit(op_add32,EAX,EDX);
	}

	//cut the upper bits so that it is 26 bits signed
	dsp_rec_se(x86e,EAX,26);

	//Write to MAD_OUT_NV wire :)
	x86e.Emit(op_mov32,MAD_OUT_NV,EAX);
}

//Reads  : INPUTS,MAD_OUT
//Writes : EFREG,TEMP,FRC_REG,ADRS_REG,MEM_WT_DATA
void dsp_rec_EFO_FB(x86_block& x86e,_INST& op,u32 step,x86_gpr_reg INPUTS)
{
	nwtn(MAD_OUT);
	//MAD_OUT is s32, no sign extension needed
	x86e.Emit(op_mov32,EAX,&dsp.regs.MAD_OUT);
	//sh .. l ?
	switch(op.SHIFT)
	{
	case 0:
		x86e.Emit(op_sar32,EAX,2);
		//×1 Protected
		x86e.Emit(op_mov32,EDX,(u32)-524288);//8388608//32768//524288
		x86e.Emit(op_cmp32,EAX,EDX);
		x86e.Emit(op_cmovl32,EAX,EDX);
		x86e.Emit(op_neg32,EDX);
		x86e.Emit(op_cmp32,EAX,EDX);
		x86e.Emit(op_cmovg32,EAX,EDX);
		//protect !
		break;
	case 1:
		//×2 Protected
		x86e.Emit(op_sar32,EAX,1);

		x86e.Emit(op_mov32,EDX,(u32)-524288);//8388608//32768//524288
		x86e.Emit(op_cmp32,EAX,EDX);
		x86e.Emit(op_cmovl32,EAX,EDX);
		x86e.Emit(op_not32,EDX);
		x86e.Emit(op_cmp32,EAX,EDX);
		x86e.Emit(op_cmovg32,EAX,EDX);
		//protect !
		break;
	case 2:
		//×2 Not protected
		x86e.Emit(op_sar32,EAX,1);
		dsp_rec_se(x86e,EAX,24);
		break;
	case 3:
		//×1 Not protected
		x86e.Emit(op_sar32,EAX,1);
		x86e.Emit(op_shl32,EAX,2);
		dsp_rec_se(x86e,EAX,24);
		break;
	}

	//Write EFREG ?
	if (op.EWT)
	{
		x86e.Emit(op_mov32,EDX,EAX);
		//top 16 bits ? or lower 16 ? 
		//i use top 16, following the same rule as the input 
		x86e.Emit(op_sar32,EDX,4);

		//write :)
		x86e.Emit(op_mov16,&DSPData->EFREG[op.EWA],DX);
	}

	//Write TEMPS ?
	if (op.TWT)
	{	
		//Temps is 24 bit, stored as s32 (no conversion required)

		//write it
		x86e.Emit(op_mov32,dsp_reg_GenerateTempsAddrs(x86e,op.TWA,ECX),EAX);
	}
 
	//COMMON TO FRC_REG and ADRS_REG
	//interpolation mode : shift1=1=shift0
	//non interpolation : shift1!=1 && shift0!=1 ? ( why && ?) -- i implement it as ||

	//Write to FRC_REG ?
	if (op.FRCL)
	{
		if (op.SHIFT==3)
		{
			//FRC_REG[12:0]=Shift[23:11]
			x86e.Emit(op_mov32,ECX,EAX);
			x86e.Emit(op_sar32,ECX,11);
		}
		else
		{
			//FRC_REG[12:0]=0'Shift[11:0]
			x86e.Emit(op_mov32,ECX,EAX);
			x86e.Emit(op_and32,ECX,(1<<12)-1);//bit 12 and up are 0'd
		}
		x86e.Emit(op_mov32,&dsp.regs.FRC_REG,ECX);
	}
	
	//Write to ADDRS_REG ?
	if (op.ADRL)
	{
		if (op.SHIFT==3)
		{
			//ADRS_REG[11:0]=Shift[23,23,23,23,23,22:16]
			x86e.Emit(op_mov32,ECX,EAX);
			x86e.Emit(op_shl32,ECX,8);	//bit31=bit 23
			x86e.Emit(op_sar32,ECX,24); //bit 0 = bit16 (16+8=24)
		}
		else
		{
			//ADRS_REG[11:0]=0'Shift[23:12]
			x86e.Emit(op_mov32,ECX,EAX);
			x86e.Emit(op_sar32,ECX,12);
			x86e.Emit(op_and32,ECX,(1<<12)-1);//bit 11 and up are 0'd
		}
		x86e.Emit(op_mov32,&dsp.regs.ADRS_REG,ECX);
	}

	//MEM_WT_DATA write
	//This kills off any non protected regs (EAX,EDX,ECX)
	{
		//pack ?
		if (!op.NOFL && SUPPORT_NOFL)
		{	//yes
			x86e.Emit(op_mov32,ECX,EAX);
			x86e.Emit(op_call,x86_ptr_imm(PACK));
		}
		else
		{	//shift (look @ EFREG write for more info)
			x86e.Emit(op_sar32,EAX,8);
		}
		//data in on EAX
		x86e.Emit(op_mov32,&dsp.regs.MEM_WT_DATA,EAX);
	}

	//more stuff here
	wtn(EFREG);
	wtn(TEMPS);
	wtn(FRC_REG);
	wtn(ADRS_REG);
	wtn(MEM_WT_DATA);
}
void dsp_recompile()
{
	dsp.dyndirty=false;

	x86_block x86e;
	x86e.Init(dyna_realloc,dyna_realloc);
	
	x86e.Emit(op_push32,EBX);
	x86e.Emit(op_push32,EBP);
	x86e.Emit(op_push32,ESI);
	x86e.Emit(op_push32,EDI);

	//OK.
	//Input comes from mems, mixs and exts, as well as possible memory reads and writes
	//mems is read/write (memory loads go there), mixs and exts are read only.
	//There are various delays (registers) so i need to properly emulate (more on that later)

	//Registers that can be written : MIXS,FRC_REG,ADRS_REG,EFREG,TEMP

	//MRD, MWT, NOFL, TABLE, NXADR, ADREB, and MASA[4:0]
	//Only allowed on odd steps, when counting from 1 (2,4,6, ...).That is even steps when counting from 0 (1,3,5, ...)
	for(int step=0;step<128;++step)
	{
		u32* mpro=DSPData->MPRO+step*4;
		u32 prev_step=(step-1)&127;
		u32* prev_mpro=DSPData->MPRO+prev_step*4;
		//if its a nop just go to the next opcode
		//No, don't really do that, we need to propage opcode bits :p
		//if (mpro[0]==0 && mpro[1]==0 && mpro[2]== 0 && mpro[3]==0)
		//	continue;

		_INST op;
		_INST prev_op;
		DecodeInst(mpro,&op);
		DecodeInst(prev_mpro,&prev_op);

		//printf("[%d] "
		//	"TRA %d,TWT %d,TWA %d,XSEL %d,YSEL %d,IRA %d,IWT %d,IWA %d,TABLE %d,MWT %d,MRD %d,EWT %d,EWA %d,ADRL %d,FRCL %d,SHIFT %d,YRL %d,NEGB %d,ZERO %d,BSEL %d,NOFL %d,MASA %d,ADREB %d,NXADR %d\n"
		//	,step
		//	,op.TRA,op.TWT,op.TWA,op.XSEL,op.YSEL,op.IRA,op.IWT,op.IWA,op.TABLE,op.MWT,op.MRD,op.EWT,op.EWA,op.ADRL,op.FRCL,op.SHIFT,op.YRL,op.NEGB,op.ZERO,op.BSEL,op.NOFL,op.MASA,op.ADREB,op.NXADR);

		//Dynarec !
		_dsp_debug_step_start();
		//DSP regs are on memory
		//Wires stay on x86 regs, written to memory as fast as possible
		
		//EDI=MEM_RD_DATA_NV
		dsp_rec_DRAM_CI(x86e,prev_op,step,EDI);
		
		//;)
		//Address Generation Unit ! nothing spectacular really ...
		dsp_rec_MEM_AGU(x86e,op,step);
		
		//Calculate INPUTS wire
		//ESI : INPUTS
		dsp_rec_INPUTS(x86e,op,ESI);
		
		//:o ?
		//Write the MEMS register
		dsp_rec_MEMS_WRITE(x86e,op,step,ESI);
		
		//Write the MEM_RD_DATA regiter
		//Last use of MEM_RD_DATA_NV(EDI)
		dsp_rec_MEM_RD_DATA_WRITE(x86e,op,step,EDI);
		//EDI is now free :D
		
		//EDI is used for MAD_OUT_NV
		//Mul-add
		dsp_rec_MAD(x86e,op,step,ESI,EDI);
		
		//Effect output/ Feedback
		dsp_rec_EFO_FB(x86e,op,step,ESI);

		//Write MAD_OUT_NV
		{
			x86e.Emit(op_mov32,&dsp.regs.MAD_OUT,EDI);
			wtn(MAD_OUT);
		}
		//These are implemented here :p

		//Inputs -> Y reg
		//Last use of inputs (ESI) and its destructive at that ;p
		{
			if (op.YRL)
			{
				x86e.Emit(op_sar32,ESI,4);//[23:4]
				x86e.Emit(op_mov32,&dsp.regs.Y_REG,ESI);

			}
			wtn(Y_REG);
		}

		//NOFL delay propagation :)
		{
			//NOFL_2=NOFL_1
			x86e.Emit(op_mov32,EAX,&dsp.regs.NOFL_1);
			x86e.Emit(op_mov32,&dsp.regs.NOFL_2,EAX);
			//NOFL_1 = NOFL
			x86e.Emit(op_mov32,&dsp.regs.NOFL_1,op.NOFL);

			wtn(NOFL_2);
			wtn(NOFL_1);
		}

		//MWT_1/MRD_1 propagation
		{
			//MWT_1=MWT
			x86e.Emit(op_mov32,&dsp.regs.MWT_1,op.MWT);
			//MRD_1=MRD
			x86e.Emit(op_mov32,&dsp.regs.MRD_1,op.MRD);

			wtn(MWT_1);
			wtn(MRD_1);
		}

		_dsp_debug_step_end();
	}

	//Need to decrement MDEC_CT here :)
	x86e.Emit(op_pop32,EDI);
	x86e.Emit(op_pop32,ESI);
	x86e.Emit(op_pop32,EBP);
	x86e.Emit(op_pop32,EBX);
	x86e.Emit(op_ret);
	x86e.Generate();
}



void dsp_print_mame();
void dsp_step_mame();
void dsp_emu_grandia();
void dsp_step()
{
	//clear output reg
	memset(DSPData->EFREG,0,sizeof(DSPData->EFREG));

	if (dsp.dyndirty)
	{
		dsp.dyndirty=false;
		//dsp_print_mame();
		dsp_recompile();
	}
	//dsp_step_mame();
	//dsp_emu_grandia();
	
	//run the code :p
	((void (*)())&dsp.DynCode)();

	dsp.regs.MDEC_CT--;
	if (dsp.regs.MDEC_CT==0)
		dsp.regs.MDEC_CT=dsp.RBL;
	//here ? or before ?
	//memset(DSP->MIXS,0,4*16);
}

void dsp_writenmem(u32 addr)
{
	addr-=0x3000;
	//COEF : native
	//MEMS : native
	//MPRO : native
	if (addr>=0x400 && addr<0xC00)
	{
		dsp.dyndirty=true;
	}

	/*
	//buffered DSP state
	//24 bit wide
	u32 TEMP[128];
	//24 bit wide
	u32 MEMS[32];
	//20 bit wide
	s32 MIXS[16];
	*/
}

void dsp_readmem(u32 addr)
{
	//nothing ? :p
}
#else

void dsp_init() { }
void dsp_term() { }
void dsp_step() { }
void dsp_writenmem(u32 addr) { }
#endif