/*
 * Copyright (c) 2012 Wojtek Kaniewski <wojtekka@toxygen.net>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

#include <stdio.h>
#include <string.h>

#define IMM_FORMAT "0x%x"
//#define IMM_FORMAT "%d"
#define ADDR_FORMAT "0x%x"

static inline unsigned int rol(unsigned int value, unsigned int shift)
{
	shift &= 31;

	return (value >> shift) | (value << (32 - shift));
}

static inline const char *condition(unsigned int insn)
{
	const char *conditions[16] = { "eq", "ne", "cs", "cc", "mi", "pl", "vs", "vc", "hi", "ls", "ge", "lt", "gt", "le", "", "nv" };
	return conditions[(insn >> 28) & 0x0f];
}

static inline const char *register_name(unsigned int reg)
{
	const char *register_names[16] = { "r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12", "sp", "lr", "pc" };
	return register_names[reg & 0x0f];
}

static const char *register_list(unsigned int list, char *buf, size_t buf_len)
{
	int i;

	buf[0] = 0;

	for (i = 0; i < 16; i++)
	{
		if ((list >> i) & 1)
		{
			snprintf(buf + strlen(buf), buf_len - strlen(buf), "%s%s", (buf[0] == 0) ? "" : ",", register_name(i));
		}
	}

	return buf;
}

static const char *shift(unsigned int insn, char *buf, size_t buf_len)
{
	unsigned int imm = (insn >> 7) & 0x1f;
	const char *rn = register_name(insn >> 8);
	unsigned int type = (insn >> 4) & 0x07;

	switch (type)
	{
	case 0:
		snprintf(buf, buf_len, (imm != 0) ? ",lsl #%d" : "", imm);
		break;
	case 1:
		snprintf(buf, buf_len, ",lsl %s", rn);
		break;
	case 2:
		snprintf(buf, buf_len, ",lsr #%d", imm ? imm : 32);
		break;
	case 3:
		snprintf(buf, buf_len, ",lsr %s", rn);
		break;
	case 4:
		snprintf(buf, buf_len, ",asr #%d", imm ? imm : 32);
		break;
	case 5:
		snprintf(buf, buf_len, ",asr %s", rn);
		break;
	case 6:
		snprintf(buf, buf_len, (imm != 0) ? ",ror #%d" : ",rrx", imm);
		break;
	case 7:
		snprintf(buf, buf_len, ",ror %s", rn);
		break;
	}

	return buf;
}

static const char *immediate(unsigned int imm, int negative, int show_if_zero, char *buf, size_t buf_len)
{
	if (imm || show_if_zero)
	{
		snprintf(buf, buf_len, ",#%s" IMM_FORMAT, (negative) ? "-" : "", imm);
		return buf;
	}

	return "";
}

static int data_processing(unsigned int pc, unsigned int insn, char *buf, size_t buf_len)
{
	unsigned int oper = (insn >> 21) & 15;
	const char *names[16] = { "and", "eor", "sub", "rsb", "add", "adc", "sbc", "rsc", "tst", "teq", "cmp", "cmn", "orr", "mov", "bic", "mvn" };
	const char *name;
	const char *s;
	unsigned int rd;
	unsigned int rn;
	int is_move = ((oper == 13) || (oper == 15));
	int is_test = ((oper >= 8) && (oper <= 11));
	char tmp_buf[64];

	name = names[oper];
	s = ((insn >> 20) & 1) ? "s" : "";
	rn = (insn >> 16) & 15;
	rd = (insn >> 12) & 15;

	/* mov r0,r0,r0 is a nop */
	if (insn == 0xe1a00000)
	{
		snprintf(buf, buf_len, "nop");
		return 1;
	}

	/* mrs */
	if ((insn & 0x0fbf0fff) == 0x010f0000)
	{
		const char *psr = ((insn >> 22) & 1) ? "spsr" : "cpsr";
		const char *rd = register_name(insn >> 12);

		snprintf(buf, buf_len, "mrs%s %s,%s", condition(insn), rd, psr);

		return 1;
	}

	/* msr flag only*/
	if ((insn & 0x0db0f000) == 0x0120f000)
	{
		const char *psr = ((insn >> 22) & 1) ? "spsr" : "cpsr";
		const char *suffix;

		switch ((insn >> 16) & 15)
		{
		case 9:
			suffix = "";
			break;
		case 8:
			suffix = "_f";
			break;
		case 1:
			suffix = "_c";
			break;
		default:
			return 0;
		}

		if ((insn >> 25) & 1)
		{
			unsigned int imm = rol(insn & 0x000000ff, ((insn >> 8) & 15) * 2);

			snprintf(buf, buf_len, "msr%s %s%s,#" IMM_FORMAT, condition(insn), psr, suffix, imm);
		}
		else
		{
			const char *rm = register_name(insn >> 0);

			if (((insn >> 4) & 255) != 0)
			{
				return 0;
			}

			snprintf(buf, buf_len, "msr%s %s%s,%s", condition(insn), psr, suffix, rm);
		}

		return 1;
	}

	if (((insn >> 25) & 1) == 0)
	{
		unsigned int rm;

		rm = (insn & 15);

		if (is_move)
		{
			snprintf(buf, buf_len, "%s%s%s %s,%s%s", name, condition(insn), s, register_name(rd), register_name(rm), shift(insn, tmp_buf, sizeof(tmp_buf)));
		}
		else if (is_test)
		{
			snprintf(buf, buf_len, "%s%s %s,%s%s", name, condition(insn), register_name(rn), register_name(rm), shift(insn, tmp_buf, sizeof(tmp_buf)));
		}
		else
		{
			snprintf(buf, buf_len, "%s%s%s %s,%s,%s%s", name, condition(insn), s, register_name(rd), register_name(rn), register_name(rm), shift(insn, tmp_buf, sizeof(tmp_buf)));
		}
	}
	else if ((insn & 0x0fb00000) == 0x03000000)
	{
		unsigned int imm;
		char *half = (insn & 0x00400000) ? "t" : "w";

		imm = (insn & 0x00000fff) | ((insn & 0x000f0000) >> 4);

		snprintf(buf, buf_len, "mov%s%s %s%s", half, condition(insn), register_name(rd), immediate(imm, 0, 1, tmp_buf, sizeof(tmp_buf)));
	}
	else
	{
		unsigned int imm;

		imm = rol(insn & 0x000000ff, ((insn >> 8) & 15) * 2);

		if (is_move)
		{
			snprintf(buf, buf_len, "%s%s%s %s%s", name, condition(insn), s, register_name(rd), immediate(imm, 0, 1, tmp_buf, sizeof(tmp_buf)));
		}
		else if (is_test)
		{
			snprintf(buf, buf_len, "%s%s %s%s", name, condition(insn), register_name(rn), immediate(imm, 0, 1, tmp_buf, sizeof(tmp_buf)));
		}
		else
		{
			snprintf(buf, buf_len, "%s%s%s %s,%s%s", name, condition(insn), s, register_name(rd), register_name(rn), immediate(imm, 0, 1, tmp_buf, sizeof(tmp_buf)));
		}
	}

	return 1;
}

static int branch(unsigned int pc, unsigned int insn, char *buf, size_t buf_len)
{
	const char *link = ((insn >> 24) & 1) ? "l" : "";
	unsigned int address;
	unsigned int offset;

	offset = insn & 0x00ffffff;

	if ((offset & 0x00800000) != 0)
	{
		offset |= 0xff000000;
	}

	address = pc + 8 + (offset << 2);

	snprintf(buf, buf_len, "b%s%s " ADDR_FORMAT, link, condition(insn), address);

	return 1;
}

static int multiply(unsigned int pc, unsigned int insn, char *buf, size_t buf_len)
{
	const char *rd = register_name(insn >> 16);
	const char *rn = register_name(insn >> 12);
	const char *rs = register_name(insn >> 8);
	const char *rm = register_name(insn >> 0);
	const char *s = ((insn >> 20) & 1) ? "s" : "";
	int mla = (insn >> 21) & 1;

	snprintf(buf, buf_len, (mla) ? "mla%s%s %s,%s,%s,%s" : "mul%s%s %s,%s,%s", condition(insn), s, rd, rm, rs, rn);

	return 1;
}

static int multiply_long(unsigned int pc, unsigned int insn, char *buf, size_t buf_len)
{
	const char *rh = register_name(insn >> 16);
	const char *rl = register_name(insn >> 12);
	const char *rs = register_name(insn >> 8);
	const char *rm = register_name(insn >> 0);
	const char *u = ((insn >> 22) & 1) ? "s" : "u";
	const char *s = ((insn >> 20) & 1) ? "s" : "";
	const char *name = ((insn >> 21) & 1) ? "mlal" : "mull";

	snprintf(buf, buf_len, "%s%s%s%s %s,%s,%s,%s", u, name, condition(insn), s, rl, rh, rm, rs);

	return 1;
}

static int single_data_swap(unsigned int pc, unsigned int insn, char *buf, size_t buf_len)
{
	const char *rn = register_name(insn >> 16);
	const char *rd = register_name(insn >> 12);
	const char *rm = register_name(insn >> 0);
	const char *b = ((insn >> 22) & 1) ? "b" : "";

	snprintf(buf, buf_len, "swp%s%s %s,%s,[%s]", condition(insn), b, rd, rm, rn);

	return 1;
}

static int branch_and_exchange(unsigned int pc, unsigned int insn, char *buf, size_t buf_len)
{
	const char *rn = register_name(insn >> 0);
	const char *l = ((insn >> 5) & 1) ? "l" : "";

	snprintf(buf, buf_len, "b%sx%s %s", l, condition(insn), rn);

	return 1;
}

static int halfword_data_transfer(unsigned int pc, unsigned int insn, char *buf, size_t buf_len)
{
	const char *rn = register_name(insn >> 16);
	const char *rd = register_name(insn >> 12);
	const char *name = ((insn >> 20) & 1) ? "ldr" : "str";
	const char *w = ((insn >> 21) & 1) ? "!" : "";
	int sign = (insn >> 23) & 1;
	int pre = (insn >> 24) & 1;
	const char *suffix = "";
	char tmp_buf[64];

	switch ((insn >> 5) & 3)
	{
	case 0:
		name = "swp";
		break;
	case 1:
		suffix = "h";
		break;
	case 2:
		suffix = "sb";
		break;
	case 3:
		suffix = "sh";
		break;
	}

	if ((insn >> 22) & 1)
	{
		unsigned int imm = ((insn >> 4) & 0xf0) | (insn & 0x0f);

		snprintf(buf, buf_len, (pre) ? "%s%s%s %s,[%s%s]%s" : "%s%s%s %s,[%s],%s%s", name, condition(insn), suffix, rd, rn, immediate(imm, !sign, 0, tmp_buf, sizeof(tmp_buf)), w);
	}
	else
	{
		const char *rm = register_name(insn >> 0);

		snprintf(buf, buf_len, (pre) ? "%s%s%s %s,[%s,%s%s]%s" : "%s%s%s %s,[%s],%s%s%s", name, condition(insn), suffix, rd, rn, sign ? "" : "-", rm, w);
	}

	return 1;
}

static int single_data_transfer(unsigned int pc, unsigned int insn, char *buf, size_t buf_len)
{
	const char *rn = register_name(insn >> 16);
	const char *rd = register_name(insn >> 12);
	const char *name = ((insn >> 20) & 1) ? "ldr" : "str";
	const char *w = ((insn >> 21) & 1) ? "!" : "";
	const char *b = ((insn >> 22) & 1) ? "b" : "";
	int sign = (insn >> 23) & 1;
	int pre = (insn >> 24) & 1;
	char tmp_buf[64];

	if ((insn >> 25) & 1)
	{
		const char *rm = register_name(insn >> 0);

		snprintf(buf, buf_len, (pre) ? "%s%s%s %s,[%s,%s%s%s]%s" : "%s%s%s %s,[%s],%s%s%s%s", name, condition(insn), b, rd, rn, sign ? "" : "-", rm, shift(insn, tmp_buf, sizeof(tmp_buf)), w);
	}
	else
	{
		unsigned int imm = insn & 0x00000fff;

		snprintf(buf, buf_len, (pre) ? "%s%s%s %s,[%s%s]%s" : "%s%s%s %s,[%s]%s%s", name, condition(insn), b, rd, rn, immediate(imm, !sign, 0, tmp_buf, sizeof(tmp_buf)), w);
	}

	return 1;
}

static int block_data_transfer(unsigned int pc, unsigned int insn, char *buf, size_t buf_len)
{
	const char *s = ((insn >> 22) & 1) ? "^" : "";
	const char *w = ((insn >> 21) & 1) ? "!" : "";
	int load = (insn >> 20) & 1;
	const char *name = (load) ? "ldm" : "stm";
	const char *ldm_stubs[4] = { "fa", "fd", "ea", "ed" };
	const char *stm_stubs[4] = { "ed", "ea", "fd", "fa" };
	int stub_idx = (insn >> 23) & 3;
	const char *stub = (load) ? ldm_stubs[stub_idx] : stm_stubs[stub_idx];
	char tmp_buf[64];

	snprintf(buf, buf_len, "%s%s%s %s%s, {%s}%s", name, condition(insn), stub, register_name(insn >> 16), w, register_list(insn & 0xffff, tmp_buf, sizeof(tmp_buf)), s);

	return 1;
}

static int coprocessor_data_transfer(unsigned int pc, unsigned int insn, char *buf, size_t buf_len)
{
	const char *name = ((insn >> 20) & 1) ? "ldc" : "stc";
	const char *rn = register_name(insn >> 16);
	int sign = (insn >> 23) & 1;
	const char *l = ((insn >> 22) & 1) ? "l" : "";
	const char *w = ((insn >> 21) & 1) ? "!" : "";
	int pre = (insn >> 24) & 1;
	unsigned int cp = (insn >> 8) & 15;
	unsigned int cd = (insn >> 12) & 15;
	unsigned int imm = (insn >> 0) & 255;
	char tmp_buf[64];

	snprintf(buf, buf_len, (pre) ? "%s%s%s p%d,cr%d,[%s%s]%s" : "%s%s%s p%d,cr%d,[%s]%s%s", name, condition(insn), l, cp, cd, rn, immediate(imm, !sign, 0, tmp_buf, sizeof(tmp_buf)), w);

	return 1;
}

static int coprocessor_data_operation(unsigned int pc, unsigned int insn, char *buf, size_t buf_len)
{
	snprintf(buf, buf_len, "cdp%s p%d,%d,cr%d,cr%d,cr%d,{%d}", condition(insn), (insn >> 8) & 15, (insn >> 20) & 15, (insn >> 12) & 15, (insn >> 16) & 15, (insn >> 0) & 15, (insn >> 5) & 7);

	return 1;
}

static int coprocessor_register_transfer(unsigned int pc, unsigned int insn, char *buf, size_t buf_len)
{
	const char *name = ((insn >> 20) & 1) ? "mrc" : "mcr";
	unsigned int cn = (insn >> 16) & 15;
	const char *rd = register_name(insn >> 12);
	unsigned int expr1 = (insn >> 21) & 7;
	unsigned int expr2 = (insn >> 5) & 7;
	unsigned int cp = (insn >> 8) & 15;
	unsigned int cm = (insn >> 0) & 15;

	snprintf(buf, buf_len, "%s%s p%d,%d,%s,cr%d,cr%d,{%d}", name, condition(insn), cp, expr1, rd, cn, cm, expr2);

	return 1;
}

static int software_interrupt(unsigned int pc, unsigned int insn, char *buf, size_t buf_len)
{
	snprintf(buf, buf_len, "swi%s %u", condition(insn), insn & 0x00ffffff);

	return 1;
}

int disarm(uintptr_t pc, uint32_t insn, char *buf, size_t buf_len, unsigned long *addr)
{
	*addr = 0;

	if ((insn & 0x0fffffd0) == 0x012fff10)
		return branch_and_exchange(pc, insn, buf, buf_len);

	if ((insn & 0x0fb00ff0) == 0x01000090)
		return single_data_swap(pc, insn, buf, buf_len);

	if ((insn & 0x0fc000f0) == 0x00000090)
		return multiply(pc, insn, buf, buf_len);

	if ((insn & 0x0f8000f0) == 0x00800090)
		return multiply_long(pc, insn, buf, buf_len);
	
	if ((insn & 0x0f000010) == 0x0e000000)
		return coprocessor_data_operation(pc, insn, buf, buf_len);

	if ((insn & 0x0f000010) == 0x0e000010)
		return coprocessor_register_transfer(pc, insn, buf, buf_len);
	
	if ((insn & 0x0f000000) == 0x0f000000)
		return software_interrupt(pc, insn, buf, buf_len);

	if ((insn & 0x0e000090) == 0x00000090)
		return halfword_data_transfer(pc, insn, buf, buf_len);

	if ((insn & 0x0e000000) == 0x08000000)
		return block_data_transfer(pc, insn, buf, buf_len);

	if ((insn & 0x0e000000) == 0x0a000000) {
		*addr = (unsigned long)pc+8 + ((unsigned long)(insn << 8) >> 6);
		return branch(pc, insn, buf, buf_len);
	}

	if ((insn & 0x0e000000) == 0x0c000000)
		return coprocessor_data_transfer(pc, insn, buf, buf_len);

	if ((insn & 0x0c000000) == 0x00000000)
		return data_processing(pc, insn, buf, buf_len);

	if ((insn & 0x0c000000) == 0x04000000)
		return single_data_transfer(pc, insn, buf, buf_len);

	return 0;
}

