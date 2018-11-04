#pragma once
#include "types.h"
#include "x86_op_classes.h"
#if HOST_OS == OS_DARWIN
	#include <TargetConditionals.h>
#endif

using namespace std;
//Oh god , x86 is a sooo badly designed opcode arch -_-

const char* DissasmClass(x86_opcode_class opcode);

#define REG_CLASS(regv) (regv>>16)
#define REG_ID(regv) (regv&0xFFFF)

/*
	X64 details !

	x64 needs special stuff for 8 bit registers, as there are some registers available only on non rex opcodes
	class   |  x86  | x64
	reg_GPR8| 8 bit | 8 bit base + 'old'
*/
enum reg_class
{
	reg_GPR8=0<<16,     //8 bit regs   (al,cl,dl,bl,ah,cd,dh,bh // r0b .. r3b)
	reg_GPR16=1<<16,    //16 bit regs  (ax,cx,dx,bx,sp,bp,si,di // ax,cx,dx,bx,sp,bp,si,di,r8w,r9w,r10w,r11w,r12w,r13w,r14w,r15w // r0w .. r15w)
	reg_GPR32=2<<16,    //32 bit regs  (eax,ecx,edx,ebx,esp,ebp,esi,edi)
	reg_MMX=3<<16,      //mmx regs     (mm0 .. mm7 // mm0 .. mm15)
	reg_SSE=4<<16,      //sse regs     (xmm0 .. xmm7 // xmm0 .. xmm15)
#ifdef X64
	reg_GPR8_64=6<<5,   //             (r8b .. r15b)
	reg_GPR8L_64=6<<5,  //             (r4b,r5b,r6b,r7b)
	reg_GPR64=7<<5,     //             (rax,rcx,rdx,rbx,rsp,rbp,rsi,rdi,r8,r9,r10,r11,r12,r13,r14,r15 // r0 .. r15)
#endif
};
//Enum of all registers
enum x86_reg
{
//32 bit

	EAX=reg_GPR32,
	ECX,
	EDX,
	EBX,
	ESP,
	EBP,
	ESI,
	EDI,

#ifdef X64
	R0d=reg_GPR32,	//these are the same as EAX .. EDI
	R1d,
	R2d,
	R3d,
	R4d,
	R5d,
	R6d,
	R7d,
	R8d,
	R9d,
	R10d,
	R11d,
	R12d,
	R13d,
	R14d,
	R15d,
#endif

//64 bit

#ifdef X64
	R0q=reg_GPR64,
	R1q,
	R2q,
	R3q,
	R4q,
	R5q,
	R6q,
	R7q,
	R8q,
	R9q,
	R10q,
	R11q,
	R12q,
	R13q,
	R14q,
	R15q,
#endif
	
	//8 bit

	AL=reg_GPR8,
	CL,
	DL,
	BL,

	AH,	//these are ONLY available on x86 mode.They will possibly added later  for x64...
	CH,
	DH,
	BH,

#ifdef X64
	R0b=reg_GPR8,	//AL
	R1b,			//CL
	R2b,			//DL
	R3b,			//BL
	R4b=reg_GPR8L_64+4,
	R5b,
	R6b,
	R7b,
	R8b=reg_GPR8_64+4,
	R9b,
	R10b,
	R11b,
	R12b,
	R13b,
	R14b,
	R15b,
#endif

//16 bit

	AX=reg_GPR16,
	CX,
	DX,
	BX,
	SP,
	BP,
	SI,
	DI,

#ifdef X64
	R0w=reg_GPR16,	//these are the same as AX .. DI
	R1w,
	R2w,
	R3w,
	R4w,
	R5w,
	R6w,
	R7w,
	R8w,
	R9w,
	R10w,
	R11w,
	R12w,
	R13w,
	R14w,
	R15w,
#endif

//XMM (SSE)

	XMM0=reg_SSE,
	XMM1,
	XMM2,
	XMM3,
	XMM4,
	XMM5,
	XMM6,
	XMM7,
#ifdef X64
	XMM8,
	XMM9,
	XMM10,
	XMM11,
	XMM12,
	XMM13,
	XMM14,
	XMM15,
#endif

#ifdef USE_MM
	//mmx (? will it be supported by the emitter?) -> probably no , SSE2 mainly replaces em w/ integer XMM math
	MM0=reg_MMX,
	MM1,
	MM2,
	MM3,
	MM4,
	MM5,
	MM6,
	MM7,
#endif

	//misc :p
	NO_REG=-1,
	ERROR_REG=-2,
};

#define x86_sse_reg x86_reg
#define x86_gpr_reg x86_reg

//memory management !
typedef void* dyna_reallocFP(void*ptr,u32 oldsize,u32 newsize);
typedef void* dyna_finalizeFP(void* ptr,u32 oldsize,u32 newsize);

//define it here cus we use it on label type ;)
class x86_block;
// a label
struct /*__declspec(dllexport)*/ x86_Label
{
	u32 target_opcode;
	u8 patch_sz;
	x86_block* owner;
	bool marked;
	void* GetPtr();
};
//An empty type that we will use as ptr type.This is ptr-reference
struct /*__declspec(dllexport)*/  x86_ptr
{
	union
	{
		void* ptr;
		unat ptr_int;
	};
	static x86_ptr create(unat ptr);
	x86_ptr(void* ptr)
	{
		this->ptr=ptr;
	}
};
//This is ptr/imm (for call/jmp)
struct /*__declspec(dllexport)*/  x86_ptr_imm
{
	union
	{
		void* ptr;
		unat ptr_int;
	};
	static x86_ptr_imm create(unat ptr);
	x86_ptr_imm(void* ptr)
	{
		this->ptr=ptr;
	}

#if HOST_CPU != CPU_X64
#if !defined(WIN32) && !defined(TARGET_OS_MAC)
	template<typename Rv, typename ...Args>
	x86_ptr_imm(Rv(* ptr)(Args...))
	{
		this->ptr= reinterpret_cast<void*>(ptr);
	}
#endif

    template<typename Rv, typename ...Args>
    x86_ptr_imm(Rv(DYNACALL * ptr)(Args...))
    {
        this->ptr= reinterpret_cast<void*>(ptr);
    }
#endif
};

enum x86_mrm_mod
{
	mod_RI,			//[reg]
	mod_RI_disp,	//[reg+disp]
	mod_DISP,		//[disp]
	mod_REG,		//reg
	mod_SIB,		//[reg1*scale+reg2], reg2 can be NO_REG , reg1 can't
	mod_SIB_disp	//[(reg1*scale+reg2)+disp], reg2 can be NO_REG , reg1 can't
};
enum x86_sib_scale
{
	sib_scale_1,
	sib_scale_2,
	sib_scale_4,
	sib_scale_8
};
//shit
struct x86_mrm_t
{
	u8 flags;
	u8 modrm;
	u8 sib;
	u32 disp;
};

/*__declspec(dllexport)*/ x86_mrm_t x86_mrm(x86_reg base);
/*__declspec(dllexport)*/ x86_mrm_t x86_mrm(x86_reg base,x86_ptr disp);
/*__declspec(dllexport)*/ x86_mrm_t x86_mrm(x86_reg base,x86_reg index);
/*__declspec(dllexport)*/ x86_mrm_t x86_mrm(x86_reg index,x86_sib_scale scale,x86_ptr disp);
/*__declspec(dllexport)*/ x86_mrm_t x86_mrm(x86_reg base,x86_reg index,x86_sib_scale scale,x86_ptr disp);


struct code_patch
{
	u8 type;//0 = 8 bit , 2 = 16 bit  , 4 = 32 bit , 16[flag] is label
	union
	{
		void* dest;		//ptr for patch
		x86_Label* lbl;	//lbl for patch
	};
	u32 offset;			//offset in opcode stream :)
};

struct /*__declspec(dllexport)*/ x86_block_externs
{
	void Apply(void* code_base);
	bool Modify(u32 offs,u8* dst);
	void Free();
	~x86_block_externs();
};

//A block of x86 code :p
class /*__declspec(dllexport)*/ x86_block
{
private:
	void* _labels;
	void ApplyPatches(u8* base);
	dyna_reallocFP* ralloc;
	dyna_finalizeFP* allocfin;
public:
	void* _patches;

	u8* x86_buff;
	u32 x86_indx;
	u32 x86_size;
	bool do_realloc;

	u32 opcode_count;

	x86_block();
	~x86_block();
	void x86_buffer_ensure(u32 size);

	void  write8(u32 value);
	void  write16(u32 value);
	void  write32(u32 value);

	//init things
	void Init(dyna_reallocFP* ral,dyna_finalizeFP* alf);

	//Generates code.
	void* Generate();
	x86_block_externs* GetExterns();
	//void CopyTo(void* to);

	//Will free any used resources except generated code
	void Free();

	//Label related code
	//NOTE : Label position in mem must not change
	void CreateLabel(x86_Label* lbl,bool mark,u32 sz);
	//Allocate a label and create it :).Will be deleted when calling free and/or destructor
	x86_Label* CreateLabel(bool mark,u32 sz);
	void MarkLabel(x86_Label* lbl);

	//When we want to keep info to mark opcodes dead , there is no need to create labels :p
	//Get an index to next emitted opcode
	u32 GetOpcodeIndex();

	//opcode Emitters

	//no param
	void Emit(x86_opcode_class op);
	//1 param
	//reg
	void Emit(x86_opcode_class op,x86_reg reg);
	//smrm
	void Emit(x86_opcode_class op,x86_ptr mem);
	//mrm
	void Emit(x86_opcode_class op,x86_mrm_t mrm);
	//imm
	void Emit(x86_opcode_class op,u32 imm);
	//ptr_imm
	void Emit(x86_opcode_class op,x86_ptr_imm disp);
	//lbl
	void Emit(x86_opcode_class op,x86_Label* lbl);

	//2 param
	//reg,reg, reg1 is written
	void Emit(x86_opcode_class op,x86_reg reg1,x86_reg reg2);
	//reg,smrm, reg is written
	void Emit(x86_opcode_class op,x86_reg reg,x86_ptr mem);
	//reg,mrm, reg is written
	void Emit(x86_opcode_class op,x86_reg reg1,x86_mrm_t mrm);
	//reg,imm, reg is written
	void Emit(x86_opcode_class op,x86_reg reg,u32 imm);
	//smrm,reg, mem is written
	void Emit(x86_opcode_class op,x86_ptr mem,x86_reg reg);
	//smrm,imm, mem is written
	void Emit(x86_opcode_class op,x86_ptr mem,u32 imm);

	//mrm,reg, mrm is written
	void Emit(x86_opcode_class op,x86_mrm_t mrm,x86_reg reg);
	//mrm,imm, mrm is written
	void Emit(x86_opcode_class op,x86_mrm_t mrm,u32 imm);

	//3 param
	//reg,reg,imm, reg1 is written
	void Emit(x86_opcode_class op,x86_reg reg1,x86_reg reg2,u32 imm);
	//reg,mrm,imm, reg1 is written
	void Emit(x86_opcode_class op,x86_reg reg,x86_ptr mem,u32 imm);
	//reg,mrm,imm, reg1 is written
	void Emit(x86_opcode_class op,x86_reg reg,x86_mrm_t mrm,u32 imm);
};
