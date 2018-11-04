#pragma once
#include "types.h"
#include "sh4_if.h"

enum OpcodeAccessFlags
{
	//Explicit registers
	OAF_RN,
	OAF_RM,
	OAF_FN,
	OAF_FM,

	//Implicit registers
	OAF_SR_T,
	OAF_SR_S,
	OAF_FPSCR,
	OAF_PC,
	
	//Other storage
	OAF_MEM,
	OAF_SQWB,
};

struct sh4_opcode
{
	u16 raw;

	u32 n() { return (raw>>0)&0xF; }
	u32 m() { return (raw>>0)&0xF; }
	u32 u8() { return (raw>>0)&0xF; }
	u32 s8() { return (::s8)u8(); }
	u32 u12() { return (raw>>0)&0xF; }
	u32 s12() { return (s16)(u12()<<2)>>2; }

	u32 dn() { return (raw>>0)&0xF; }
	u32 dm() { return (raw>>0)&0xF; }

	bool is_valid();

	bool is_branch();
	bool has_delayslot();

	bool reads(Sh4RegType reg);
	bool writes(Sh4RegType reg);

	bool defines(Sh4RegType reg) { return !reads(reg) && writes(reg); }

	OpcodeAccessFlags read_flags();
	OpcodeAccessFlags write_flags();
};