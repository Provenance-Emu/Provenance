/*

	This is a header file that can create 
	a) Shil opcode enums
	b) Shil opcode classes/portable C implementation ("canonical" implementation)
	c) The routing table for canonical implementations
	d) Cookies (if you're really lucky)

*/
#if HOST_CPU == CPU_ARM && !defined(_ANDROID) && 0
//FIXME: Fix extern function support on shil, or remove these
extern "C" void ftrv_asm(float* fd,float* fn, float* fm);
extern "C" f32 fipr_asm(float* fn, float* fm);
#define ftrv_impl ftrv_asm
#define fipr_impl fipr_asm
#endif

#ifndef ftrv_impl
#define ftrv_impl f1
#endif

#ifndef fipr_impl
#define fipr_impl f1
#endif

#define fsca_impl fsca_table

#if SHIL_MODE==0
//generate enums ..
	#define SHIL_START enum shilop {
	#define SHIL_END shop_max, };

	#define shil_opc(name) shop_##name,
	#define shil_opc_end()

	#define shil_canonical(rv,name,args,code)
	#define shil_compile(code)
#elif  SHIL_MODE==1
	//generate structs ...
	#define SHIL_START
	#define SHIL_END

	#define shil_opc(name) struct shil_opcl_##name { 
	#define shil_opc_end() };

	#define shil_canonical(rv,name,args,code) struct name { static rv impl args { code } };
	
	#define shil_cf_arg_u32(x) ngen_CC_Param(op,&op->x,CPT_u32);
	#define shil_cf_arg_f32(x) ngen_CC_Param(op,&op->x,CPT_f32);
	#define shil_cf_arg_ptr(x) ngen_CC_Param(op,&op->x,CPT_ptr);
	#define shil_cf_rv_u32(x) ngen_CC_Param(op,&op->x,CPT_u32rv);
	#define shil_cf_rv_f32(x) ngen_CC_Param(op,&op->x,CPT_f32rv);
	#define shil_cf_rv_u64(x) ngen_CC_Param(op,&op->rd,CPT_u64rvL); ngen_CC_Param(op,&op->rd2,CPT_u64rvH);
	#define shil_cf_ext(x) ngen_CC_Call(op,(void*)&x);
	#define shil_cf(x) shil_cf_ext(x::impl)

	#define shil_compile(code) static void compile(shil_opcode* op) { ngen_CC_Start(op); code ngen_CC_Finish(op); }
#elif  SHIL_MODE==2
	//generate struct declarations ...
	#define SHIL_START
	#define SHIL_END

	#define shil_opc(name) struct shil_opcl_##name { 
	#define shil_opc_end() };

	#define shil_canonical(rv,name,args,code) struct name { static rv impl args; };
	#define shil_compile(code) static void compile(shil_opcode* op);
#elif  SHIL_MODE==3
	//generate struct list ...
	

	#define SHIL_START \
	shil_chfp* shil_chf[] = {

	#define SHIL_END };

	#define shil_opc(name) &shil_opcl_##name::compile,
	#define shil_opc_end()

	#define shil_canonical(rv,name,args,code)
	#define shil_compile(code)
#elif SHIL_MODE==4
//generate name strings ..
	#define SHIL_START const char* shilop_str[]={
	#define SHIL_END };

	#define shil_opc(name) #name,
	#define shil_opc_end()

	#define shil_canonical(rv,name,args,code)
	#define shil_compile(code)
#else
#error Invalid SHIL_MODE
#endif



#if SHIL_MODE==1 || SHIL_MODE==2
//only in structs we use the code :)
#include <math.h>
#include "types.h"
#include "shil.h"
#include "decoder.h"
#include "../sh4_rom.h"



#define BIN_OP_I_BASE(code,type,rtype) \
shil_canonical \
( \
rtype,f1,(type r1,type r2), \
	code \
) \
 \
shil_compile \
( \
	shil_cf_arg_##type(rs2); \
	shil_cf_arg_##type(rs1); \
	shil_cf(f1); \
	shil_cf_rv_##rtype(rd); \
)

#define UN_OP_I_BASE(code,type) \
shil_canonical \
( \
type,f1,(type r1), \
	code \
) \
 \
shil_compile \
( \
	shil_cf_arg_##type(rs1); \
	shil_cf(f1); \
	shil_cf_rv_##type(rd); \
)


#define BIN_OP_I(z) BIN_OP_I_BASE( return r1 z r2; ,u32,u32)

#define BIN_OP_I2(tp,z) BIN_OP_I_BASE( return ((tp) r1) z ((tp) r2); ,u32,u32)
#define BIN_OP_I3(z,w) BIN_OP_I_BASE( return (r1 z r2) w; ,u32,u32)
#define BIN_OP_I4(tp,z,rt,pt) BIN_OP_I_BASE( return ((tp)(pt)r1) z ((tp)(pt)r2); ,u32,rt)
	
#define BIN_OP_F(z) BIN_OP_I_BASE( return r1 z r2; ,f32,f32)
#define BIN_OP_FU(z) BIN_OP_I_BASE( return r1 z r2; ,f32,u32)

#define UN_OP_I(z) UN_OP_I_BASE( return z (r1); ,u32)
#define UN_OP_F(z) UN_OP_I_BASE( return z (r1); ,f32)

#define shil_recimp() \
shil_compile( \
	die("This opcode requires native dynarec implementation"); \
)

#else

#define BIN_OP_I(z)

#define BIN_OP_I2(tp,z)
#define BIN_OP_I3(z,w)
#define BIN_OP_I4(tp,z,rt,k)
	
#define BIN_OP_F(z)
#define BIN_OP_FU(z)

#define UN_OP_I(z)
#define UN_OP_F(z)
#define shil_recimp()
#endif



SHIL_START


//shop_mov32
shil_opc(mov32)
shil_recimp()
shil_opc_end()

//shop_mov64
shil_opc(mov64)
shil_recimp()
shil_opc_end()

//Special opcodes
shil_opc(jdyn)
shil_recimp()
shil_opc_end()

shil_opc(jcond)
shil_recimp()
shil_opc_end()

//shop_ifb
shil_opc(ifb)
shil_recimp()
shil_opc_end()

//mem io
shil_opc(readm)	
shil_recimp()
shil_opc_end()

shil_opc(writem)
shil_recimp()
shil_opc_end()

//Canonical impl. opcodes !
shil_opc(sync_sr)
shil_canonical
(
void, f1, (),
	UpdateSR();
)
shil_compile
(
	shil_cf(f1);
)
shil_opc_end()

shil_opc(sync_fpscr)
shil_canonical
(
void, f1, (),
	UpdateFPSCR();
)
shil_compile
(
	shil_cf(f1);
)
shil_opc_end()

//shop_and
shil_opc(and)
BIN_OP_I(&)
shil_opc_end()

//shop_or
shil_opc(or)
BIN_OP_I(|)
shil_opc_end()

//shop_xor
shil_opc(xor)
BIN_OP_I(^)
shil_opc_end()

//shop_not
shil_opc(not)
UN_OP_I(~)
shil_opc_end()

//shop_add
shil_opc(add)
BIN_OP_I(+)
shil_opc_end()

//shop_sub
shil_opc(sub)
BIN_OP_I(-)
shil_opc_end()

//shop_neg
shil_opc(neg)
UN_OP_I(-)
shil_opc_end()

//shop_shl,
shil_opc(shl)
BIN_OP_I2(u32,<<)
shil_opc_end()

//shop_shr
shil_opc(shr)
BIN_OP_I2(u32,>>)
shil_opc_end()

//shop_sar
shil_opc(sar)
BIN_OP_I2(s32,>>)
shil_opc_end()

//shop_adc	//add with carry
shil_opc(adc)
shil_canonical
(
u64,f1,(u32 r1,u32 r2,u32 C),
	u64 res=(u64)r1+r2+C;

	u64 rv;
	((u32*)&rv)[0]=res;
	((u32*)&rv)[1]=res>>32;

	/*
	//Damn macro magic//
#if HOST_CPU==CPU_X86
	verify(((u32*)&rv)[1]<=1);
	verify(C<=1);
#endif
	*/

	return rv;
)

shil_compile
(
	shil_cf_arg_u32(rs3);
	shil_cf_arg_u32(rs2);
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_u64(rd);
	//die();
)

shil_opc_end()


//shop_adc	//add with carry
shil_opc(sbc)
shil_canonical
(
u64,f1,(u32 r1,u32 r2,u32 C),
	u64 res=(u64)r1-r2-C;

	u64 rv;
	((u32*)&rv)[0]=res;
	((u32*)&rv)[1]=(res>>32)&1; //alternatively: res>>63

	/*
	//Damn macro magic//
#if HOST_CPU==CPU_X86
	verify(((u32*)&rv)[1]<=1);
	verify(C<=1);
#endif
	*/

	return rv;
)

shil_compile
(
	shil_cf_arg_u32(rs3);
	shil_cf_arg_u32(rs2);
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_u64(rd);
	//die();
)
shil_opc_end()


//shop_ror
shil_opc(ror)
shil_canonical
(
u32,f1,(u32 r1,u32 amt),
	return (r1>>amt)|(r1<<(32-amt));
)

shil_compile
(
 	shil_cf_arg_u32(rs2);
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_u32(rd);
)

shil_opc_end()


//shop_rocl
shil_opc(rocl)
shil_canonical
(
u64,f1,(u32 r1,u32 r2),
	u64 rv;
	((u32*)&rv)[0]=(r1<<1)|r2;
	((u32*)&rv)[1]=r1>>31;
	return rv;
)

shil_compile
(
	shil_cf_arg_u32(rs2);
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_u64(rd);
)

shil_opc_end()

//shop_rocr
shil_opc(rocr)
shil_canonical
(
u64,f1,(u32 r1,u32 r2),
	u64 rv;
	((u32*)&rv)[0]=(r1>>1)|(r2<<31);
	((u32*)&rv)[1]=r1&1;
	return rv;
)

shil_compile
(
	shil_cf_arg_u32(rs2);
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_u64(rd);
)

shil_opc_end()

//shop_swaplb -- swap low bytes
shil_opc(swaplb)
shil_canonical
(
u32,f1,(u32 r1),
	return (r1 & 0xFFFF0000) | ((r1&0xFF)<<8) | ((r1>>8)&0xFF);
)

shil_compile
(
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_u32(rd);
)

shil_opc_end()


//shop_swap -- swap all bytes in word
shil_opc(swap)
shil_canonical
(
u32,f1,(u32 r1),
	return (r1 >>24) | ((r1 >>16)&0xFF00) |((r1&0xFF00)<<8) | (r1<<24);
)

shil_compile
(
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_u32(rd);
)

shil_opc_end()

//shop_shld
shil_opc(shld)
shil_canonical
(
u32,f1,(u32 r1,u32 r2),
	u32 sgn = r2 & 0x80000000;
	if (sgn == 0)
		return r1 << (r2 & 0x1F);
	else if ((r2 & 0x1F) == 0)
	{
		return 0;
	}
	else
		return r1 >> ((~r2 & 0x1F) + 1);
)

shil_compile
(
	shil_cf_arg_u32(rs2);
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_u32(rd);
	//die();
)
shil_opc_end()

//shop_shad
shil_opc(shad)
shil_canonical
(
u32,f1,(s32 r1,u32 r2),
	u32 sgn = r2 & 0x80000000;
	if (sgn == 0)
		return r1 << (r2 & 0x1F);
	else if ((r2 & 0x1F) == 0)
	{
		return r1>>31;
	}
	else
		return r1 >> ((~r2 & 0x1F) + 1);
)

shil_compile
(
	shil_cf_arg_u32(rs2);
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_u32(rd);
	//die();
)

shil_opc_end()

//shop_ext_s8
shil_opc(ext_s8)
shil_canonical
(
u32,f1,(u32 r1),
	return (s8)r1;
)

shil_compile
(
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_u32(rd);
	//die();
)

shil_opc_end()


//shop_ext_s16
shil_opc(ext_s16)
shil_canonical
(
u32,f1,(u32 r1),
	return (s16)r1;
)

shil_compile
(
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_u32(rd);
	//die();
)

shil_opc_end()

//shop_mul_u16
shil_opc(mul_u16)
BIN_OP_I4(u16,*,u32,u32)
shil_opc_end()

//shop_mul_s16
shil_opc(mul_s16)
BIN_OP_I4(s16,*,u32,u32)
shil_opc_end()

//no difference between signed and unsigned when only the lower
//32 bis are used !
//shop_mul_i32
shil_opc(mul_i32)
BIN_OP_I4(s32,*,u32,u32)
shil_opc_end()

//shop_mul_u64
shil_opc(mul_u64)
BIN_OP_I4(u64,*,u64,u32)
shil_opc_end()

//shop_mul_s64
shil_opc(mul_s64)
BIN_OP_I4(s64,*,u64,s32)
shil_opc_end()

//shop_div32u	//divide 32 bits, unsigned
shil_opc(div32u)
shil_canonical
(
u64,f1,(u32 r1,u32 r2),
	u32 quo=r1/r2;
	u32 rem=r1%r2;

	u64 rv;
	((u32*)&rv)[0]=quo;
	((u32*)&rv)[1]=rem;
	return rv;
)

shil_compile
(
	shil_cf_arg_u32(rs2);
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_u64(rd);
	//die();
)

shil_opc_end()

//shop_div32s	//divide 32 bits, signed
shil_opc(div32s)
shil_canonical
(
u64,f1,(s32 r1,s32 r2),
	u32 quo=r1/r2;
	u32 rem=r1%r2;

	u64 rv;
	((u32*)&rv)[0]=quo;
	((u32*)&rv)[1]=rem;
	return rv;
)

shil_compile
(
	shil_cf_arg_u32(rs2);
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_u64(rd);
	//die();
)

shil_opc_end()

//shop_div32p2	//div32, fixup step (part 2)
shil_opc(div32p2)
shil_canonical
(
u32,f1,(s32 a,s32 b,s32 T),
	if (!T)
	{
		a-=b;
	}

	return a;
)

shil_compile
(
	shil_cf_arg_u32(rs3);
	shil_cf_arg_u32(rs2);
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_u32(rd);
	//die();
)

shil_opc_end()

//debug_3
shil_opc(debug_3)
shil_canonical
(
void,f1,(u32 r1,u32 r2,u32 r3),
	printf("%08X, %08X, %08X\n",r1,r2,r3);
)

shil_compile
(
	shil_cf_arg_u32(rs3);
	shil_cf_arg_u32(rs2);
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
)

shil_opc_end()

//debug_1
shil_opc(debug_1)
shil_canonical
(
void,f1,(u32 r1),
	printf("%08X\n",r1);
)

shil_compile
(
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
)

shil_opc_end()

//shop_cvt_f2i_t	//float to integer : truncate
shil_opc(cvt_f2i_t)
shil_canonical
(
u32,f1,(f32 f1),
	if (f1 > 2147483520.0f) // IEEE 754: 0x4effffff
		return 0x7fffffff;
	else
		return (s32)f1;
)

shil_compile
(
	shil_cf_arg_f32(rs1);
	shil_cf(f1);
	shil_cf_rv_u32(rd);
	//die();
)

shil_opc_end()

//shop_cvt_i2f_n	//integer to float : nearest
shil_opc(cvt_i2f_n)
shil_canonical
(
f32,f1,(u32 r1),
	return (float)(s32)r1;
)

shil_compile
(
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_f32(rd);
	//die();
)

shil_opc_end()

//shop_cvt_i2f_z	//integer to float : round to zero
shil_opc(cvt_i2f_z)
shil_canonical
(
f32,f1,(u32 r1),
	return (float)(s32)r1;
)

shil_compile
(
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_f32(rd);
	//die();
)

shil_opc_end()


//pref !
shil_opc(pref)
shil_canonical
(
void,f1,(u32 r1),
	if ((r1>>26) == 0x38) do_sqw_mmu(r1);
)

shil_canonical
(
void,f2,(u32 r1),
	if ((r1>>26) == 0x38) do_sqw_nommu(r1,sq_both);
)

shil_compile
(
	shil_cf_arg_u32(rs1);
	if (CCN_MMUCR.AT)
	{
		shil_cf(f1);
	}
	else
	{
		shil_cf(f2);
	}
	//die();
)

shil_opc_end()

//shop_test
shil_opc(test)
BIN_OP_I3(&,== 0)
shil_opc_end()

//shop_seteq	//equal
shil_opc(seteq)
BIN_OP_I2(s32,==)
shil_opc_end()

//shop_setge	//>=, signed (greater equal)
shil_opc(setge)
BIN_OP_I2(s32,>=)
shil_opc_end()

//shop_setgt //>, signed	 (greater than)
shil_opc(setgt)
BIN_OP_I2(s32,>)
shil_opc_end()

//shop_setae	//>=, unsigned (above equal)
shil_opc(setae)
BIN_OP_I2(u32,>=)
shil_opc_end()

//shop_setab	//>, unsigned (above)
shil_opc(setab)
BIN_OP_I2(u32,>)
shil_opc_end()

//shop_setpeq //set if any pair of bytes is equal
shil_opc(setpeq)
shil_canonical
(
u32,f1,(u32 r1,u32 r2),
	u32 temp = r1 ^ r2;

	if ( (temp&0xFF000000) && (temp&0x00FF0000) && (temp&0x0000FF00) && (temp&0x000000FF) )
		return 0;
	else
		return 1;		
)

shil_compile
(
 	shil_cf_arg_u32(rs2);
	shil_cf_arg_u32(rs1);
	shil_cf(f1);
	shil_cf_rv_u32(rd);
)

shil_opc_end()

//here come the moving points

//shop_fadd
shil_opc(fadd)
BIN_OP_F(+)
shil_opc_end()

//shop_fsub
shil_opc(fsub)
BIN_OP_F(-)
shil_opc_end()

//shop_fmul
shil_opc(fmul)
BIN_OP_F(*)
shil_opc_end()

//shop_fdiv
shil_opc(fdiv)
BIN_OP_F(/)
shil_opc_end()

//shop_fabs
shil_opc(fabs)
UN_OP_F(fabsf)
shil_opc_end()

//shop_fneg
shil_opc(fneg)
UN_OP_F(-)
shil_opc_end()

//shop_fsqrt
shil_opc(fsqrt)
UN_OP_F(sqrtf)
shil_opc_end()


//shop_fipr
shil_opc(fipr)
shil_canonical
(
f32,f1,(float* fn, float* fm),
	float idp;

	idp=fn[0]*fm[0];
	idp+=fn[1]*fm[1];
	idp+=fn[2]*fm[2];
	idp+=fn[3]*fm[3];

	return idp;
)

shil_compile
(
	shil_cf_arg_ptr(rs2);
	shil_cf_arg_ptr(rs1);
	shil_cf(fipr_impl);
	shil_cf_rv_f32(rd);
	//die();
)

shil_opc_end()



//shop_ftrv
shil_opc(ftrv)
shil_canonical
(
void,f1,(float* fd,float* fn, float* fm),
	float v1;
	float v2;
	float v3;
	float v4;

	v1 = fm[0]  * fn[0] +
		 fm[4]  * fn[1] +
		 fm[8]  * fn[2] +
		 fm[12] * fn[3];

	v2 = fm[1]  * fn[0] +
		 fm[5]  * fn[1] +
		 fm[9]  * fn[2] +
		 fm[13] * fn[3];

	v3 = fm[2]  * fn[0] +
		 fm[6]  * fn[1] +
		 fm[10] * fn[2] +
		 fm[14] * fn[3];

	v4 = fm[3]  * fn[0] +
		 fm[7]  * fn[1] +
		 fm[11] * fn[2] +
		 fm[15] * fn[3];

	fd[0] = v1;
	fd[1] = v2;
	fd[2] = v3;
	fd[3] = v4;
)
shil_compile
(
	shil_cf_arg_ptr(rs2);
	shil_cf_arg_ptr(rs1);
	shil_cf_arg_ptr(rd);
	shil_cf(ftrv_impl);
	//die();
)
shil_opc_end()

//shop_fmac
shil_opc(fmac)
shil_canonical
(
f32,f1,(float fn, float f0,float fm),
	return fn + f0 * fm;
)
shil_compile
(
	shil_cf_arg_f32(rs3);
	shil_cf_arg_f32(rs2);
	shil_cf_arg_f32(rs1);
	shil_cf(f1);
	shil_cf_rv_f32(rd);
	//die();
)
shil_opc_end()

//shop_fsrra
shil_opc(fsrra)
UN_OP_F(1/sqrtf)
shil_opc_end()


//shop_fsca
shil_opc(fsca)

shil_canonical
(
void,fsca_native,(float* fd,u32 fixed),

	u32 pi_index=fixed&0xFFFF;

	float rads=pi_index/(65536.0f/2)*(3.14159265f)/*pi*/;

	fd[0] = sinf(rads);
	fd[1] = cosf(rads);
)
shil_canonical
(
void,fsca_table,(float* fd,u32 fixed),

	u32 pi_index=fixed&0xFFFF;

	fd[0] = sin_table[pi_index].u[0];
	fd[1] = sin_table[pi_index].u[1];
)

shil_compile
(
	shil_cf_arg_u32(rs1);
	shil_cf_arg_ptr(rd);
	shil_cf(fsca_impl);
)

shil_opc_end()


//shop_fseteq
shil_opc(fseteq)
BIN_OP_FU(==)
shil_opc_end()

//shop_fsetgt
shil_opc(fsetgt)
BIN_OP_FU(>)
shil_opc_end()



//shop_frswap
shil_opc(frswap)
shil_canonical
(
void,f1,(u64* fd1,u64* fd2,u64* fs1,u64* fs2),

	u64 temp;
	for (int i=0;i<8;i++)
	{
		temp=fs1[i];
		fd1[i]=fs2[i];
		fd2[i]=temp;
	}
)
shil_compile
(
	shil_cf_arg_ptr(rs2);
	shil_cf_arg_ptr(rs1);
	shil_cf_arg_ptr(rd);
	shil_cf_arg_ptr(rd2);
	shil_cf(f1);
)
shil_opc_end()

SHIL_END


//undefine stuff
#undef SHIL_MODE

#undef SHIL_START
#undef SHIL_END

#undef shil_opc
#undef shil_opc_end

#undef shil_canonical
#undef shil_compile


#undef BIN_OP_I

#undef BIN_OP_I2
#undef BIN_OP_I3
#undef BIN_OP_I4
	
#undef BIN_OP_F

#undef UN_OP_I
#undef UN_OP_F
#undef BIN_OP_FU
#undef shil_recimp
