//
//   Copyright (C) 2007 by sinamas <sinamas at users.sourceforge.net>
//
//   This program is free software; you can redistribute it and/or modify
//   it under the terms of the GNU General Public License version 2 as
//   published by the Free Software Foundation.
//
//   This program is distributed in the hope that it will be useful,
//   but WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//   GNU General Public License version 2 for more details.
//
//   You should have received a copy of the GNU General Public License
//   version 2 along with this program; if not, write to the
//   Free Software Foundation, Inc.,
//   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
//

#include "cpu.h"
#include "memory.h"
#include "savestate.h"

namespace gambatte {

CPU::CPU()
: mem_(Interrupter(sp, pc_))
, cycleCounter_(0)
, pc_(0x100)
, sp(0xFFFE)
, hf1(0xF)
, hf2(0xF)
, zf(0)
, cf(0x100)
, a_(0x01)
, b(0x00)
, c(0x13)
, d(0x00)
, e(0xD8)
, h(0x01)
, l(0x4D)
, skip_(false)
{
}

long CPU::runFor(unsigned long const cycles) {
	process(cycles);

	long const csb = mem_.cyclesSinceBlit(cycleCounter_);

	if (cycleCounter_ & 0x80000000)
		cycleCounter_ = mem_.resetCounters(cycleCounter_);

	return csb;
}

enum { hf2_hcf = 0x200, hf2_subf = 0x400, hf2_incf = 0x800 };

static unsigned updateHf2FromHf1(unsigned const hf1, unsigned hf2) {
	unsigned lhs  = hf1 & 0xF;
	unsigned rhs = (hf2 & 0xF) + (hf2 >> 8 & 1);
	if (hf2 & hf2_incf) {
		lhs = rhs;
		rhs = 1;
	}

	unsigned res = hf2 & hf2_subf
	             ?  lhs - rhs
	             : (lhs + rhs) << 5;

	hf2 |= res & hf2_hcf;
	return hf2;
}

static inline unsigned toF(unsigned hf2, unsigned cf, unsigned zf) {
	return ((hf2 & (hf2_subf | hf2_hcf)) | (cf & 0x100)) >> 4
	     | (zf & 0xFF ? 0 : 0x80);
}

static inline unsigned  zfFromF(unsigned f) { return ~f & 0x80; }
static inline unsigned hf2FromF(unsigned f) { return f << 4 & (hf2_subf | hf2_hcf); }
static inline unsigned  cfFromF(unsigned f) { return f << 4 & 0x100; }

void CPU::setStatePtrs(SaveState &state) {
	mem_.setStatePtrs(state);
}

void CPU::saveState(SaveState &state) {
	cycleCounter_ = mem_.saveState(state, cycleCounter_);
	hf2 = updateHf2FromHf1(hf1, hf2);

	state.cpu.cycleCounter = cycleCounter_;
	state.cpu.pc = pc_;
	state.cpu.sp = sp;
	state.cpu.a = a_;
	state.cpu.b = b;
	state.cpu.c = c;
	state.cpu.d = d;
	state.cpu.e = e;
	state.cpu.f = toF(hf2, cf, zf);
	state.cpu.h = h;
	state.cpu.l = l;
	state.cpu.skip = skip_;
}

void CPU::loadState(SaveState const &state) {
	mem_.loadState(state);

	cycleCounter_ = state.cpu.cycleCounter;
	pc_ = state.cpu.pc & 0xFFFF;
	sp = state.cpu.sp & 0xFFFF;
	a_ = state.cpu.a & 0xFF;
	b = state.cpu.b & 0xFF;
	c = state.cpu.c & 0xFF;
	d = state.cpu.d & 0xFF;
	e = state.cpu.e & 0xFF;
	zf  =  zfFromF(state.cpu.f);
	hf2 = hf2FromF(state.cpu.f);
	cf  =  cfFromF(state.cpu.f);
	h = state.cpu.h & 0xFF;
	l = state.cpu.l & 0xFF;
	skip_ = state.cpu.skip;
}

// The main reasons for the use of macros is to more conveniently be able to tweak
// which variables are local and which are not, combined with the fact that at the
// time they were written GCC had a tendency to not be able to keep hot variables
// in regs if you took an address/reference in an inline function.

#define bc() ( b << 8 | c )
#define de() ( d << 8 | e )
#define hl() ( h << 8 | l )

#define READ(dest, addr) do { (dest) = mem_.read(addr, cycleCounter); cycleCounter += 4; } while (0)
#define PC_READ(dest) do { (dest) = mem_.read(pc, cycleCounter); pc = (pc + 1) & 0xFFFF; cycleCounter += 4; } while (0)
#define FF_READ(dest, addr) do { (dest) = mem_.ff_read(addr, cycleCounter); cycleCounter += 4; } while (0)

#define WRITE(addr, data) do { mem_.write(addr, data, cycleCounter); cycleCounter += 4; } while (0)
#define FF_WRITE(addr, data) do { mem_.ff_write(addr, data, cycleCounter); cycleCounter += 4; } while (0)

#define PC_MOD(data) do { pc = data; cycleCounter += 4; } while (0)

#define PUSH(r1, r2) do { \
	sp = (sp - 1) & 0xFFFF; \
	WRITE(sp, (r1)); \
	sp = (sp - 1) & 0xFFFF; \
	WRITE(sp, (r2)); \
} while (0)

// CB OPCODES (Shifts, rotates and bits):
// swap r (8 cycles):
// Swap upper and lower nibbles of 8-bit register, reset flags, check zero flag:
#define swap_r(r) do { \
	cf = hf2 = 0; \
	zf = (r); \
	(r) = (zf << 4 | zf >> 4) & 0xFF; \
} while (0)

// rlc r (8 cycles):
// Rotate 8-bit register left, store old bit7 in CF. Reset SF and HCF, Check ZF:
#define rlc_r(r) do { \
	cf = (r) << 1; \
	zf = cf | cf >> 8; \
	(r) = zf & 0xFF; \
	hf2 = 0; \
} while (0)

// rl r (8 cycles):
// Rotate 8-bit register left through CF, store old bit7 in CF, old CF value becomes bit0. Reset SF and HCF, Check ZF:
#define rl_r(r) do { \
	unsigned const oldcf = cf >> 8 & 1; \
	cf = (r) << 1; \
	zf = cf | oldcf; \
	(r) = zf & 0xFF; \
	hf2 = 0; \
} while (0)

// rrc r (8 cycles):
// Rotate 8-bit register right, store old bit0 in CF. Reset SF and HCF, Check ZF:
#define rrc_r(r) do { \
	zf = (r); \
	cf = zf << 8; \
	(r) = (zf | cf) >> 1 & 0xFF; \
	hf2 = 0; \
} while (0)

// rr r (8 cycles):
// Rotate 8-bit register right through CF, store old bit0 in CF, old CF value becomes bit7. Reset SF and HCF, Check ZF:
#define rr_r(r) do { \
	unsigned const oldcf = cf & 0x100; \
	cf = (r) << 8; \
	(r) = zf = ((r) | oldcf) >> 1; \
	hf2 = 0; \
} while (0)

// sla r (8 cycles):
// Shift 8-bit register left, store old bit7 in CF. Reset SF and HCF, Check ZF:
#define sla_r(r) do { \
	zf = cf = (r) << 1; \
	(r) = zf & 0xFF; \
	hf2 = 0; \
} while (0)

// sra r (8 cycles):
// Shift 8-bit register right, store old bit0 in CF. bit7=old bit7. Reset SF and HCF, Check ZF:
#define sra_r(r) do { \
	cf = (r) << 8; \
	zf = (r) >> 1; \
	(r) = zf | ((r) & 0x80); \
	hf2 = 0; \
} while (0)

// srl r (8 cycles):
// Shift 8-bit register right, store old bit0 in CF. Reset SF and HCF, Check ZF:
#define srl_r(r) do { \
	zf = (r); \
	cf = (r) << 8; \
	zf >>= 1; \
	(r) = zf; \
	hf2 = 0; \
} while (0)

// bit n,r (8 cycles):
// bit n,(hl) (12 cycles):
// Test bitn in 8-bit value, check ZF, unset SF, set HCF:
#define bitn_u8(bitmask, u8) do { \
	zf = (u8) & (bitmask); \
	hf2 = hf2_hcf; \
} while (0)

#define bit0_u8(u8) bitn_u8(0x01, (u8))
#define bit1_u8(u8) bitn_u8(0x02, (u8))
#define bit2_u8(u8) bitn_u8(0x04, (u8))
#define bit3_u8(u8) bitn_u8(0x08, (u8))
#define bit4_u8(u8) bitn_u8(0x10, (u8))
#define bit5_u8(u8) bitn_u8(0x20, (u8))
#define bit6_u8(u8) bitn_u8(0x40, (u8))
#define bit7_u8(u8) bitn_u8(0x80, (u8))

// set n,r (8 cycles):
// Set bitn of 8-bit register:
#define set0_r(r) ( (r) |= 0x01 )
#define set1_r(r) ( (r) |= 0x02 )
#define set2_r(r) ( (r) |= 0x04 )
#define set3_r(r) ( (r) |= 0x08 )
#define set4_r(r) ( (r) |= 0x10 )
#define set5_r(r) ( (r) |= 0x20 )
#define set6_r(r) ( (r) |= 0x40 )
#define set7_r(r) ( (r) |= 0x80 )

// set n,(hl) (16 cycles):
// Set bitn of value at address stored in HL:
#define setn_mem_hl(n) do { \
	unsigned const hl = hl(); \
	unsigned val; \
	READ(val, hl); \
	val |= 1 << (n); \
	WRITE(hl, val); \
} while (0)

// res n,r (8 cycles):
// Unset bitn of 8-bit register:
#define res0_r(r) ( (r) &= 0xFE )
#define res1_r(r) ( (r) &= 0xFD )
#define res2_r(r) ( (r) &= 0xFB )
#define res3_r(r) ( (r) &= 0xF7 )
#define res4_r(r) ( (r) &= 0xEF )
#define res5_r(r) ( (r) &= 0xDF )
#define res6_r(r) ( (r) &= 0xBF )
#define res7_r(r) ( (r) &= 0x7F )

// res n,(hl) (16 cycles):
// Unset bitn of value at address stored in HL:
#define resn_mem_hl(n) do { \
	unsigned const hl = hl(); \
	unsigned val; \
	READ(val, hl); \
	val &= ~(1 << (n)); \
	WRITE(hl, val); \
} while (0)


// 16-BIT LOADS:
// ld rr,nn (12 cycles)
// set rr to 16-bit value of next 2 bytes in memory
#define ld_rr_nn(r1, r2) do { \
	PC_READ(r2); \
	PC_READ(r1); \
} while (0)

// push rr (16 cycles):
// Push value of register pair onto stack:
#define push_rr(r1, r2) do { \
	PUSH(r1, r2); \
	cycleCounter += 4; \
} while (0)

// pop rr (12 cycles):
// Pop two bytes off stack into register pair:
#define pop_rr(r1, r2) do { \
	READ(r2, sp); \
	sp = (sp + 1) & 0xFFFF; \
	READ(r1, sp); \
	sp = (sp + 1) & 0xFFFF; \
} while (0)

// 8-BIT ALU:
// add a,r (4 cycles):
// add a,(addr) (8 cycles):
// Add 8-bit value to A, check flags:
#define add_a_u8(u8) do { \
	hf1 = a; \
	hf2 = u8; \
	zf = cf = a + hf2; \
	a = zf & 0xFF; \
} while (0)

// adc a,r (4 cycles):
// adc a,(addr) (8 cycles):
// Add 8-bit value+CF to A, check flags:
#define adc_a_u8(u8) do { \
	hf1 = a; \
	hf2 = (cf & 0x100) | (u8); \
	zf = cf = (cf >> 8 & 1) + (u8) + a; \
	a = zf & 0xFF; \
} while (0)

// sub a,r (4 cycles):
// sub a,(addr) (8 cycles):
// Subtract 8-bit value from A, check flags:
#define sub_a_u8(u8) do { \
	hf1 = a; \
	hf2 = u8; \
	zf = cf = a - hf2; \
	a = zf & 0xFF; \
	hf2 |= hf2_subf; \
} while (0)

// sbc a,r (4 cycles):
// sbc a,(addr) (8 cycles):
// Subtract CF and 8-bit value from A, check flags:
#define sbc_a_u8(u8) do { \
	hf1 = a; \
	hf2 = hf2_subf | (cf & 0x100) | (u8); \
	zf = cf = a - ((cf >> 8) & 1) - (u8); \
	a = zf & 0xFF; \
} while (0)

// and a,r (4 cycles):
// and a,(addr) (8 cycles):
// bitwise and 8-bit value into A, check flags:
#define and_a_u8(u8) do { \
	hf2 = hf2_hcf; \
	cf = 0; \
	a &= (u8); \
	zf = a; \
} while (0)

// or a,r (4 cycles):
// or a,(hl) (8 cycles):
// bitwise or 8-bit value into A, check flags:
#define or_a_u8(u8) do { \
	cf = hf2 = 0; \
	a |= (u8); \
	zf = a; \
} while (0)

// xor a,r (4 cycles):
// xor a,(hl) (8 cycles):
// bitwise xor 8-bit value into A, check flags:
#define xor_a_u8(u8) do { \
	cf = hf2 = 0; \
	a ^= (u8); \
	zf = a; \
} while (0)

// cp a,r (4 cycles):
// cp a,(addr) (8 cycles):
// Compare (subtract without storing result) 8-bit value to A, check flags:
#define cp_a_u8(u8) do { \
	hf1 = a; \
	hf2 = u8; \
	zf = cf = a - hf2; \
	hf2 |= hf2_subf; \
} while (0)

// inc r (4 cycles):
// Increment value of 8-bit register, check flags except CF:
#define inc_r(r) do { \
	hf2 = (r) | hf2_incf; \
	zf = (r) + 1; \
	(r) = zf & 0xFF; \
} while (0)

// dec r (4 cycles):
// Decrement value of 8-bit register, check flags except CF:
#define dec_r(r) do { \
	hf2 = (r) | hf2_incf | hf2_subf; \
	zf = (r) - 1; \
	(r) = zf & 0xFF; \
} while (0)

// 16-BIT ARITHMETIC
// add hl,rr (8 cycles):
// add 16-bit register to HL, check flags except ZF:
#define add_hl_rr(rh, rl) do { \
	cf = l + (rl); \
	l = cf & 0xFF; \
	hf1 = h; \
	hf2 = (cf & 0x100) | (rh); \
	cf = h + (cf >> 8) + (rh); \
	h = cf & 0xFF; \
	cycleCounter += 4; \
} while (0)

// inc rr (8 cycles):
// Increment 16-bit register:
#define inc_rr(rh, rl) do { \
	unsigned const lowinc = (rl) + 1; \
	(rl) = lowinc & 0xFF; \
	(rh) = ((rh) + (lowinc >> 8)) & 0xFF; \
	cycleCounter += 4; \
} while (0)

// dec rr (8 cycles):
// Decrement 16-bit register:
#define dec_rr(rh, rl) do { \
	unsigned const lowdec = (rl) - 1; \
	(rl) = lowdec & 0xFF; \
	(rh) = ((rh) - (lowdec >> 8 & 1)) & 0xFF; \
	cycleCounter += 4; \
} while (0)

#define sp_plus_n(sumout) do { \
	unsigned disp; \
	PC_READ(disp); \
	disp = (disp ^ 0x80) - 0x80; \
\
	unsigned const res = sp + disp; \
	cf = sp ^ disp ^ res; \
	hf2 = cf << 5 & hf2_hcf; \
	zf = 1; \
	cycleCounter += 4; \
	(sumout) = res & 0xFFFF; \
} while (0)

// JUMPS:
// jp nn (16 cycles):
// Jump to address stored in the next two bytes in memory:
#define jp_nn() do { \
	unsigned imm0, imm1; \
	PC_READ(imm0); \
	PC_READ(imm1); \
	PC_MOD(imm1 << 8 | imm0); \
} while (0)

// jr disp (12 cycles):
// Jump to value of next (signed) byte in memory+current address:
#define jr_disp() do { \
	unsigned disp; \
	PC_READ(disp); \
	disp = (disp ^ 0x80) - 0x80; \
	PC_MOD((pc + disp) & 0xFFFF); \
} while (0)

// CALLS, RESTARTS AND RETURNS:
// call nn (24 cycles):
// Jump to 16-bit immediate operand and push return address onto stack:
#define call_nn() do { \
	unsigned const npc = (pc + 2) & 0xFFFF; \
	jp_nn(); \
	PUSH(npc >> 8, npc & 0xFF); \
} while (0)

// rst n (16 Cycles):
// Push present address onto stack, jump to address n (one of 00h,08h,10h,18h,20h,28h,30h,38h):
#define rst_n(n) do { \
	PUSH(pc >> 8, pc & 0xFF); \
	PC_MOD(n); \
} while (0)

// ret (16 cycles):
// Pop two bytes from the stack and jump to that address:
#define ret() do { \
	unsigned low, high; \
	pop_rr(high, low); \
	PC_MOD(high << 8 | low); \
} while (0)

void CPU::process(unsigned long const cycles) {
	mem_.setEndtime(cycleCounter_, cycles);
	mem_.updateInput();

	unsigned char a = a_;
	unsigned long cycleCounter = cycleCounter_;

	while (mem_.isActive()) {
		unsigned short pc = pc_;

		if (mem_.halted()) {
			if (cycleCounter < mem_.nextEventTime()) {
				unsigned long cycles = mem_.nextEventTime() - cycleCounter;
				cycleCounter += cycles + (-cycles & 3);
			}
		} else while (cycleCounter < mem_.nextEventTime()) {
			unsigned char opcode;

			PC_READ(opcode);

			if (skip_) {
				pc = (pc - 1) & 0xFFFF;
				skip_ = false;
			}

			switch (opcode) {
			case 0x00:
				break;
			case 0x01:
				ld_rr_nn(b, c);
				break;
			case 0x02:
				WRITE(bc(), a);
				break;
			case 0x03:
				inc_rr(b, c);
				break;
			case 0x04:
				inc_r(b);
				break;
			case 0x05:
				dec_r(b); 
				break;
			case 0x06:
				PC_READ(b);
				break;

				// rlca (4 cycles):
				// Rotate 8-bit register A left, store old bit7 in CF. Reset SF, HCF, ZF:
			case 0x07:
				cf = a << 1;
				a = (cf | cf >> 8) & 0xFF;
				hf2 = 0;
				zf = 1;
				break;

				// ld (nn),SP (20 cycles):
				// Put value of SP into address given by next 2 bytes in memory:
			case 0x08:
				{
					unsigned imml, immh;
					PC_READ(imml);
					PC_READ(immh);

					unsigned const addr = immh << 8 | imml;
					WRITE(addr, sp & 0xFF);
					WRITE((addr + 1) & 0xFFFF, sp >> 8);
				}

				break;

			case 0x09:
				add_hl_rr(b, c);
				break;
			case 0x0A:
				READ(a, bc());
				break;
			case 0x0B:
				dec_rr(b, c);
				break;
			case 0x0C:
				inc_r(c);
				break;
			case 0x0D:
				dec_r(c);
				break;
			case 0x0E:
				PC_READ(c);
				break;

				// rrca (4 cycles):
				// Rotate 8-bit register A right, store old bit0 in CF. Reset SF, HCF, ZF:
			case 0x0F:
				cf = a << 8 | a;
				a = cf >> 1 & 0xFF;
				hf2 = 0;
				zf = 1;
				break;

				// stop (4 cycles):
				// Halt CPU and LCD display until button pressed:
			case 0x10:
				pc = (pc + 1) & 0xFFFF;

				cycleCounter = mem_.stop(cycleCounter);

				if (cycleCounter < mem_.nextEventTime()) {
					unsigned long cycles = mem_.nextEventTime() - cycleCounter;
					cycleCounter += cycles + (-cycles & 3);
				}

				break;

			case 0x11:
				ld_rr_nn(d, e);
				break;
			case 0x12:
				WRITE(de(), a);
				break;
			case 0x13:
				inc_rr(d, e);
				break;
			case 0x14:
				inc_r(d);
				break;
			case 0x15:
				dec_r(d);
				break;
			case 0x16:
				PC_READ(d);
				break;

				// rla (4 cycles):
				// Rotate 8-bit register A left through CF, store old bit7 in CF,
				// old CF value becomes bit0. Reset SF, HCF, ZF:
			case 0x17:
				{
					unsigned oldcf = cf >> 8 & 1;
					cf = a << 1;
					a = (cf | oldcf) & 0xFF;
				}

				hf2 = 0;
				zf = 1;
				break;

			case 0x18:
				jr_disp();
				break;
			case 0x19:
				add_hl_rr(d, e);
				break;
			case 0x1A:
				READ(a, de());
				break;
			case 0x1B:
				dec_rr(d, e);
				break;
			case 0x1C:
				inc_r(e);
				break;
			case 0x1D:
				dec_r(e);
				break;
			case 0x1E:
				PC_READ(e);
				break;

				// rra (4 cycles):
				// Rotate 8-bit register A right through CF, store old bit0 in CF,
				// old CF value becomes bit7. Reset SF, HCF, ZF:
			case 0x1F:
				{
					unsigned oldcf = cf & 0x100;
					cf = a << 8;
					a = (a | oldcf) >> 1;
				}

				hf2 = 0;
				zf = 1;
				break;

				// jr nz,disp (12;8 cycles):
				// Jump to value of next (signed) byte in memory+current address if ZF is unset:
			case 0x20:
				if (zf & 0xFF) {
					jr_disp();
				} else {
					PC_MOD((pc + 1) & 0xFFFF);
				}

				break;

			case 0x21: ld_rr_nn(h, l); break;

				// ldi (hl),a (8 cycles):
				// Put A into memory address in hl. Increment HL:
			case 0x22:
				{
					unsigned addr = hl();
					WRITE(addr, a);

					addr = (addr + 1) & 0xFFFF;
					l = addr;
					h = addr >> 8;
				}

				break;

			case 0x23:
				inc_rr(h, l);
				break;
			case 0x24:
				inc_r(h);
				break;
			case 0x25:
				dec_r(h);
				break;
			case 0x26:
				PC_READ(h);
				break;

				// daa (4 cycles):
				// Adjust register A to correctly represent a BCD. Check ZF, HF and CF:
			case 0x27:
				hf2 = updateHf2FromHf1(hf1, hf2);

				{
					unsigned correction = cf & 0x100 ? 0x60 : 0x00;

					if (hf2 & hf2_hcf)
						correction |= 0x06;

					if (!(hf2 &= hf2_subf)) {
						if ((a & 0x0F) > 0x09)
							correction |= 0x06;
						if (a > 0x99)
							correction |= 0x60;

						a += correction;
					} else
						a -= correction;

					cf = correction << 2 & 0x100;
					zf = a;
					a &= 0xFF;
				}

				break;

				// jr z,disp (12;8 cycles):
				// Jump to value of next (signed) byte in memory+current address if ZF is set:
			case 0x28:
				if (zf & 0xFF) {
					PC_MOD((pc + 1) & 0xFFFF);
				} else {
					jr_disp();
				}

				break;

			case 0x29:
				add_hl_rr(h, l);
				break;

				// ldi a,(hl) (8 cycles):
				// Put value at address in hl into A. Increment HL:
			case 0x2A:
				{
					unsigned addr = hl();
					READ(a, addr);

					addr = (addr + 1) & 0xFFFF;
					l = addr;
					h = addr >> 8;
				}

				break;

			case 0x2B:
				dec_rr(h, l);
				break;
			case 0x2C:
				inc_r(l);
				break;
			case 0x2D:
				dec_r(l);
				break;
			case 0x2E:
				PC_READ(l);
				break;

				// cpl (4 cycles):
				// Complement register A. (Flip all bits), set SF and HCF:
			case 0x2F:
				hf2 = hf2_subf | hf2_hcf;
				a ^= 0xFF;
				break;

				// jr nc,disp (12;8 cycles):
				// Jump to value of next (signed) byte in memory+current address if CF is unset:
			case 0x30:
				if (cf & 0x100) {
					PC_MOD((pc + 1) & 0xFFFF);
				} else {
					jr_disp();
				}

				break;

				// ld sp,nn (12 cycles)
				// set sp to 16-bit value of next 2 bytes in memory
			case 0x31:
				{
					unsigned imml, immh;
					PC_READ(imml);
					PC_READ(immh);

					sp = immh << 8 | imml;
				}

				break;

				// ldd (hl),a (8 cycles):
				// Put A into memory address in hl. Decrement HL:
			case 0x32:
				{
					unsigned addr = hl();
					WRITE(addr, a);

					addr = (addr - 1) & 0xFFFF;
					l = addr;
					h = addr >> 8;
				}

				break;

			case 0x33:
				sp = (sp + 1) & 0xFFFF;
				cycleCounter += 4;
				break;

				// inc (hl) (12 cycles):
				// Increment value at address in hl, check flags except CF:
			case 0x34:
				{
					unsigned const addr = hl();
					READ(hf2, addr);
					zf = hf2 + 1;
					WRITE(addr, zf & 0xFF);
					hf2 |= hf2_incf;
				}

				break;

				// dec (hl) (12 cycles):
				// Decrement value at address in hl, check flags except CF:
			case 0x35:
				{
					unsigned const addr = hl();
					READ(hf2, addr);
					zf = hf2 - 1;
					WRITE(addr, zf & 0xFF);
					hf2 |= hf2_incf | hf2_subf;
				}

				break;

				// ld (hl),n (12 cycles):
				// set memory at address in hl to value of next byte in memory:
			case 0x36:
				{
					unsigned imm;
					PC_READ(imm);
					WRITE(hl(), imm);
				}

				break;

				// scf (4 cycles):
				// Set CF. Unset SF and HCF:
			case 0x37:
				cf = 0x100;
				hf2 = 0;
				break;

				// jr c,disp (12;8 cycles):
				// Jump to value of next (signed) byte in memory+current address if CF is set:
			case 0x38:
				if (cf & 0x100) {
					jr_disp();
				} else {
					PC_MOD((pc + 1) & 0xFFFF);
				}

				break;

				// add hl,sp (8 cycles):
				// add SP to HL, check flags except ZF:
			case 0x39:
				cf = l + sp;
				l = cf & 0xFF;
				hf1 = h;
				hf2 = ((cf ^ sp) & 0x100) | sp >> 8;
				cf >>= 8;
				cf += h;
				h = cf & 0xFF;
				cycleCounter += 4;
				break;

				// ldd a,(hl) (8 cycles):
				// Put value at address in hl into A. Decrement HL:
			case 0x3A:
				{
					unsigned addr = hl();
					a = mem_.read(addr, cycleCounter);
					cycleCounter += 4;

					addr = (addr - 1) & 0xFFFF;
					l = addr;
					h = addr >> 8;
				}

				break;

			case 0x3B:
				sp = (sp - 1) & 0xFFFF;
				cycleCounter += 4;
				break;

			case 0x3C:
				inc_r(a);
				break;
			case 0x3D:
				dec_r(a);
				break;
			case 0x3E:
				PC_READ(a);
				break;

				// ccf (4 cycles):
				// Complement CF (unset if set vv.) Unset SF and HCF.
			case 0x3F:
				cf ^= 0x100;
				hf2 = 0;
				break;

			case 0x40: /*b = b;*/ break;
			case 0x41: b = c; break;
			case 0x42: b = d; break;
			case 0x43: b = e; break;
			case 0x44: b = h; break;
			case 0x45: b = l; break;
			case 0x46: READ(b, hl()); break;
			case 0x47: b = a; break;

			case 0x48: c = b; break;
			case 0x49: /*c = c;*/ break;
			case 0x4A: c = d; break;
			case 0x4B: c = e; break;
			case 0x4C: c = h; break;
			case 0x4D: c = l; break;
			case 0x4E: READ(c, hl()); break;
			case 0x4F: c = a; break;

			case 0x50: d = b; break;
			case 0x51: d = c; break;
			case 0x52: /*d = d;*/ break;
			case 0x53: d = e; break;
			case 0x54: d = h; break;
			case 0x55: d = l; break;
			case 0x56: READ(d, hl()); break;
			case 0x57: d = a; break;

			case 0x58: e = b; break;
			case 0x59: e = c; break;
			case 0x5A: e = d; break;
			case 0x5B: /*e = e;*/ break;
			case 0x5C: e = h; break;
			case 0x5D: e = l; break;
			case 0x5E: READ(e, hl()); break;
			case 0x5F: e = a; break;

			case 0x60: h = b; break;
			case 0x61: h = c; break;
			case 0x62: h = d; break;
			case 0x63: h = e; break;
			case 0x64: /*h = h;*/ break;
			case 0x65: h = l; break;
			case 0x66: READ(h, hl()); break;
			case 0x67: h = a; break;

			case 0x68: l = b; break;
			case 0x69: l = c; break;
			case 0x6A: l = d; break;
			case 0x6B: l = e; break;
			case 0x6C: l = h; break;
			case 0x6D: /*l = l;*/ break;
			case 0x6E: READ(l, hl()); break;
			case 0x6F: l = a; break;

			case 0x70: WRITE(hl(), b); break;
			case 0x71: WRITE(hl(), c); break;
			case 0x72: WRITE(hl(), d); break;
			case 0x73: WRITE(hl(), e); break;
			case 0x74: WRITE(hl(), h); break;
			case 0x75: WRITE(hl(), l); break;

				// halt (4 cycles):
			case 0x76:
				if (!mem_.ime()
					&& (   mem_.ff_read(0x0F, cycleCounter)
					     & mem_.ff_read(0xFF, cycleCounter) & 0x1F)) {
					if (mem_.isCgb())
						cycleCounter += 4;
					else
						skip_ = true;
				} else {
					mem_.halt();

					if (cycleCounter < mem_.nextEventTime()) {
						unsigned long cycles = mem_.nextEventTime() - cycleCounter;
						cycleCounter += cycles + (-cycles & 3);
					}
				}

				break;

			case 0x77: WRITE(hl(), a); break;
			case 0x78: a = b; break;
			case 0x79: a = c; break;
			case 0x7A: a = d; break;
			case 0x7B: a = e; break;
			case 0x7C: a = h; break;
			case 0x7D: a = l; break;
			case 0x7E: READ(a, hl()); break;
			case 0x7F: /*a = a;*/ break;

			case 0x80: add_a_u8(b); break;
			case 0x81: add_a_u8(c); break;
			case 0x82: add_a_u8(d); break;
			case 0x83: add_a_u8(e); break;
			case 0x84: add_a_u8(h); break;
			case 0x85: add_a_u8(l); break;
			case 0x86: { unsigned data; READ(data, hl()); add_a_u8(data); } break;
			case 0x87: add_a_u8(a); break;

			case 0x88: adc_a_u8(b); break;
			case 0x89: adc_a_u8(c); break;
			case 0x8A: adc_a_u8(d); break;
			case 0x8B: adc_a_u8(e); break;
			case 0x8C: adc_a_u8(h); break;
			case 0x8D: adc_a_u8(l); break;
			case 0x8E: { unsigned data; READ(data, hl()); adc_a_u8(data); } break;
			case 0x8F: adc_a_u8(a); break;

			case 0x90: sub_a_u8(b); break;
			case 0x91: sub_a_u8(c); break;
			case 0x92: sub_a_u8(d); break;
			case 0x93: sub_a_u8(e); break;
			case 0x94: sub_a_u8(h); break;
			case 0x95: sub_a_u8(l); break;
			case 0x96: { unsigned data; READ(data, hl()); sub_a_u8(data); } break;

				// A-A is always 0:
			case 0x97:
				hf2 = hf2_subf;
				cf = zf = a = 0;
				break;

			case 0x98: sbc_a_u8(b); break;
			case 0x99: sbc_a_u8(c); break;
			case 0x9A: sbc_a_u8(d); break;
			case 0x9B: sbc_a_u8(e); break;
			case 0x9C: sbc_a_u8(h); break;
			case 0x9D: sbc_a_u8(l); break;
			case 0x9E: { unsigned data; READ(data, hl()); sbc_a_u8(data); } break;
			case 0x9F: sbc_a_u8(a); break;

			case 0xA0: and_a_u8(b); break;
			case 0xA1: and_a_u8(c); break;
			case 0xA2: and_a_u8(d); break;
			case 0xA3: and_a_u8(e); break;
			case 0xA4: and_a_u8(h); break;
			case 0xA5: and_a_u8(l); break;
			case 0xA6: { unsigned data; READ(data, hl()); and_a_u8(data); } break;

				// A&A will always be A:
			case 0xA7:
				zf = a;
				cf = 0;
				hf2 = hf2_hcf;
				break;

			case 0xA8: xor_a_u8(b); break;
			case 0xA9: xor_a_u8(c); break;
			case 0xAA: xor_a_u8(d); break;
			case 0xAB: xor_a_u8(e); break;
			case 0xAC: xor_a_u8(h); break;
			case 0xAD: xor_a_u8(l); break;
			case 0xAE: { unsigned data; READ(data, hl()); xor_a_u8(data); } break;

				// A^A will always be 0:
			case 0xAF: cf = hf2 = zf = a = 0; break;

			case 0xB0: or_a_u8(b); break;
			case 0xB1: or_a_u8(c); break;
			case 0xB2: or_a_u8(d); break;
			case 0xB3: or_a_u8(e); break;
			case 0xB4: or_a_u8(h); break;
			case 0xB5: or_a_u8(l); break;
			case 0xB6: { unsigned data; READ(data, hl()); or_a_u8(data); } break;

				// A|A will always be A:
			case 0xB7:
				zf = a;
				hf2 = cf = 0;
				break;

			case 0xB8: cp_a_u8(b); break;
			case 0xB9: cp_a_u8(c); break;
			case 0xBA: cp_a_u8(d); break;
			case 0xBB: cp_a_u8(e); break;
			case 0xBC: cp_a_u8(h); break;
			case 0xBD: cp_a_u8(l); break;
			case 0xBE: { unsigned data; READ(data, hl()); cp_a_u8(data); } break;

				// A always equals A:
			case 0xBF:
				cf = zf = 0;
				hf2 = hf2_subf;
				break;

				// ret nz (20;8 cycles):
				// Pop two bytes from the stack and jump to that address, if ZF is unset:
			case 0xC0:
				cycleCounter += 4;

				if (zf & 0xFF)
					ret();

				break;

			case 0xC1:
				pop_rr(b, c);
				break;

				// jp nz,nn (16;12 cycles):
				// Jump to address stored in next two bytes in memory if ZF is unset:
			case 0xC2:
				if (zf & 0xFF) {
					jp_nn();
				} else {
					PC_MOD((pc + 2) & 0xFFFF);
					cycleCounter += 4;
				}

				break;

			case 0xC3:
				jp_nn();
				break;

				// call nz,nn (24;12 cycles):
				// Push address of next instruction onto stack and then jump to
				// address stored in next two bytes in memory, if ZF is unset:
			case 0xC4:
				if (zf & 0xFF) {
					call_nn();
				} else {
					PC_MOD((pc + 2) & 0xFFFF);
					cycleCounter += 4;
				}

				break;

			case 0xC5:
				push_rr(b, c);
				break;
			case 0xC6:
				{
					unsigned data;
					PC_READ(data);
					add_a_u8(data);
				}

				break;

			case 0xC7:
				rst_n(0x00);
				break;

				// ret z (20;8 cycles):
				// Pop two bytes from the stack and jump to that address, if ZF is set:
			case 0xC8:
				cycleCounter += 4;

				if (!(zf & 0xFF))
					ret();

				break;

				// ret (16 cycles):
				// Pop two bytes from the stack and jump to that address:
			case 0xC9:
				ret();
				break;

				// jp z,nn (16;12 cycles):
				// Jump to address stored in next two bytes in memory if ZF is set:
			case 0xCA:
				if (zf & 0xFF) {
					PC_MOD((pc + 2) & 0xFFFF);
					cycleCounter += 4;
				} else {
					jp_nn();
				}

				break;


				// CB OPCODES (Shifts, rotates and bits):
			case 0xCB:
				PC_READ(opcode);

				switch (opcode) {
				case 0x00: rlc_r(b); break;
				case 0x01: rlc_r(c); break;
				case 0x02: rlc_r(d); break;
				case 0x03: rlc_r(e); break;
				case 0x04: rlc_r(h); break;
				case 0x05: rlc_r(l); break;

					// rlc (hl) (16 cycles):
					// Rotate 8-bit value stored at address in HL left, store old bit7 in CF.
					// Reset SF and HCF. Check ZF:
				case 0x06:
					{
						unsigned const addr = hl();
						READ(cf, addr);
						cf <<= 1;
						zf = cf | (cf >> 8);
						WRITE(addr, zf & 0xFF);
						hf2 = 0;
					}

					break;

				case 0x07: rlc_r(a); break;

				case 0x08: rrc_r(b); break;
				case 0x09: rrc_r(c); break;
				case 0x0A: rrc_r(d); break;
				case 0x0B: rrc_r(e); break;
				case 0x0C: rrc_r(h); break;
				case 0x0D: rrc_r(l); break;

					// rrc (hl) (16 cycles):
					// Rotate 8-bit value stored at address in HL right, store old bit0 in CF.
					// Reset SF and HCF. Check ZF:
				case 0x0E:
					{
						unsigned const addr = hl();
						READ(zf, addr);
						cf = zf << 8;
						WRITE(addr, (zf | cf) >> 1 & 0xFF);
						hf2 = 0;
					}

					break;

				case 0x0F: rrc_r(a); break;

				case 0x10: rl_r(b); break;
				case 0x11: rl_r(c); break;
				case 0x12: rl_r(d); break;
				case 0x13: rl_r(e); break;
				case 0x14: rl_r(h); break;
				case 0x15: rl_r(l); break;

					// rl (hl) (16 cycles):
					// Rotate 8-bit value stored at address in HL left thorugh CF,
					// store old bit7 in CF, old CF value becoms bit0. Reset SF and HCF. Check ZF:
				case 0x16:
					{
						unsigned const addr = hl();
						unsigned const oldcf = cf >> 8 & 1;
						READ(cf, addr);
						cf <<= 1;
						zf = cf | oldcf;
						WRITE(addr, zf & 0xFF);
						hf2 = 0;
					}
					break;

				case 0x17: rl_r(a); break;

				case 0x18: rr_r(b); break;
				case 0x19: rr_r(c); break;
				case 0x1A: rr_r(d); break;
				case 0x1B: rr_r(e); break;
				case 0x1C: rr_r(h); break;
				case 0x1D: rr_r(l); break;

					// rr (hl) (16 cycles):
					// Rotate 8-bit value stored at address in HL right thorugh CF,
					// store old bit0 in CF, old CF value becoms bit7. Reset SF and HCF. Check ZF:
				case 0x1E:
					{
						unsigned const addr = hl();
						READ(zf, addr);

						unsigned const oldcf = cf & 0x100;
						cf = zf << 8;
						zf = (zf | oldcf) >> 1;
						WRITE(addr, zf);
						hf2 = 0;
					}

					break;

				case 0x1F: rr_r(a); break;

				case 0x20: sla_r(b); break;
				case 0x21: sla_r(c); break;
				case 0x22: sla_r(d); break;
				case 0x23: sla_r(e); break;
				case 0x24: sla_r(h); break;
				case 0x25: sla_r(l); break;

					// sla (hl) (16 cycles):
					// Shift 8-bit value stored at address in HL left, store old bit7 in CF.
					// Reset SF and HCF. Check ZF:
				case 0x26:
					{
						unsigned const addr = hl();
						READ(cf, addr);
						cf <<= 1;
						zf = cf;
						WRITE(addr, zf & 0xFF);
						hf2 = 0;
					}

					break;

				case 0x27: sla_r(a); break;

				case 0x28: sra_r(b); break;
				case 0x29: sra_r(c); break;
				case 0x2A: sra_r(d); break;
				case 0x2B: sra_r(e); break;
				case 0x2C: sra_r(h); break;
				case 0x2D: sra_r(l); break;

					// sra (hl) (16 cycles):
					// Shift 8-bit value stored at address in HL right, store old bit0 in CF,
					// bit7=old bit7. Reset SF and HCF. Check ZF:
				case 0x2E:
					{
						unsigned const addr = hl();
						READ(cf, addr);
						zf = cf >> 1;
						WRITE(addr, zf | (cf & 0x80));
						cf <<= 8;
						hf2 = 0;
					}

					break;

				case 0x2F: sra_r(a); break;

				case 0x30: swap_r(b); break;
				case 0x31: swap_r(c); break;
				case 0x32: swap_r(d); break;
				case 0x33: swap_r(e); break;
				case 0x34: swap_r(h); break;
				case 0x35: swap_r(l); break;

					// swap (hl) (16 cycles):
					// Swap upper and lower nibbles of 8-bit value stored at address in HL,
					// reset flags, check zero flag:
				case 0x36:
					{
						unsigned const addr = hl();
						READ(zf, addr);
						WRITE(addr, (zf << 4 | zf >> 4) & 0xFF);
						cf = hf2 = 0;
					}

					break;

				case 0x37: swap_r(a); break;

				case 0x38: srl_r(b); break;
				case 0x39: srl_r(c); break;
				case 0x3A: srl_r(d); break;
				case 0x3B: srl_r(e); break;
				case 0x3C: srl_r(h); break;
				case 0x3D: srl_r(l); break;

					// srl (hl) (16 cycles):
					// Shift 8-bit value stored at address in HL right,
					// store old bit0 in CF. Reset SF and HCF. Check ZF:
				case 0x3E:
					{
						unsigned const addr = hl();
						READ(cf, addr);
						zf = cf >> 1;
						WRITE(addr, zf);
						cf <<= 8;
						hf2 = 0;
					}

					break;

				case 0x3F: srl_r(a); break;

				case 0x40: bit0_u8(b); break;
				case 0x41: bit0_u8(c); break;
				case 0x42: bit0_u8(d); break;
				case 0x43: bit0_u8(e); break;
				case 0x44: bit0_u8(h); break;
				case 0x45: bit0_u8(l); break;
				case 0x46: { unsigned data; READ(data, hl()); bit0_u8(data); } break;
				case 0x47: bit0_u8(a); break;

				case 0x48: bit1_u8(b); break;
				case 0x49: bit1_u8(c); break;
				case 0x4A: bit1_u8(d); break;
				case 0x4B: bit1_u8(e); break;
				case 0x4C: bit1_u8(h); break;
				case 0x4D: bit1_u8(l); break;
				case 0x4E: { unsigned data; READ(data, hl()); bit1_u8(data); } break;
				case 0x4F: bit1_u8(a); break;

				case 0x50: bit2_u8(b); break;
				case 0x51: bit2_u8(c); break;
				case 0x52: bit2_u8(d); break;
				case 0x53: bit2_u8(e); break;
				case 0x54: bit2_u8(h); break;
				case 0x55: bit2_u8(l); break;
				case 0x56: { unsigned data; READ(data, hl()); bit2_u8(data); } break;
				case 0x57: bit2_u8(a); break;

				case 0x58: bit3_u8(b); break;
				case 0x59: bit3_u8(c); break;
				case 0x5A: bit3_u8(d); break;
				case 0x5B: bit3_u8(e); break;
				case 0x5C: bit3_u8(h); break;
				case 0x5D: bit3_u8(l); break;
				case 0x5E: { unsigned data; READ(data, hl()); bit3_u8(data); } break;
				case 0x5F: bit3_u8(a); break;

				case 0x60: bit4_u8(b); break;
				case 0x61: bit4_u8(c); break;
				case 0x62: bit4_u8(d); break;
				case 0x63: bit4_u8(e); break;
				case 0x64: bit4_u8(h); break;
				case 0x65: bit4_u8(l); break;
				case 0x66: { unsigned data; READ(data, hl()); bit4_u8(data); } break;
				case 0x67: bit4_u8(a); break;

				case 0x68: bit5_u8(b); break;
				case 0x69: bit5_u8(c); break;
				case 0x6A: bit5_u8(d); break;
				case 0x6B: bit5_u8(e); break;
				case 0x6C: bit5_u8(h); break;
				case 0x6D: bit5_u8(l); break;
				case 0x6E: { unsigned data; READ(data, hl()); bit5_u8(data); } break;
				case 0x6F: bit5_u8(a); break;

				case 0x70: bit6_u8(b); break;
				case 0x71: bit6_u8(c); break;
				case 0x72: bit6_u8(d); break;
				case 0x73: bit6_u8(e); break;
				case 0x74: bit6_u8(h); break;
				case 0x75: bit6_u8(l); break;
				case 0x76: { unsigned data; READ(data, hl()); bit6_u8(data); } break;
				case 0x77: bit6_u8(a); break;

				case 0x78: bit7_u8(b); break;
				case 0x79: bit7_u8(c); break;
				case 0x7A: bit7_u8(d); break;
				case 0x7B: bit7_u8(e); break;
				case 0x7C: bit7_u8(h); break;
				case 0x7D: bit7_u8(l); break;
				case 0x7E: { unsigned data; READ(data, hl()); bit7_u8(data); } break;
				case 0x7F: bit7_u8(a); break;

				case 0x80: res0_r(b); break;
				case 0x81: res0_r(c); break;
				case 0x82: res0_r(d); break;
				case 0x83: res0_r(e); break;
				case 0x84: res0_r(h); break;
				case 0x85: res0_r(l); break;
				case 0x86: resn_mem_hl(0); break;
				case 0x87: res0_r(a); break;

				case 0x88: res1_r(b); break;
				case 0x89: res1_r(c); break;
				case 0x8A: res1_r(d); break;
				case 0x8B: res1_r(e); break;
				case 0x8C: res1_r(h); break;
				case 0x8D: res1_r(l); break;
				case 0x8E: resn_mem_hl(1); break;
				case 0x8F: res1_r(a); break;

				case 0x90: res2_r(b); break;
				case 0x91: res2_r(c); break;
				case 0x92: res2_r(d); break;
				case 0x93: res2_r(e); break;
				case 0x94: res2_r(h); break;
				case 0x95: res2_r(l); break;
				case 0x96: resn_mem_hl(2); break;
				case 0x97: res2_r(a); break;

				case 0x98: res3_r(b); break;
				case 0x99: res3_r(c); break;
				case 0x9A: res3_r(d); break;
				case 0x9B: res3_r(e); break;
				case 0x9C: res3_r(h); break;
				case 0x9D: res3_r(l); break;
				case 0x9E: resn_mem_hl(3); break;
				case 0x9F: res3_r(a); break;

				case 0xA0: res4_r(b); break;
				case 0xA1: res4_r(c); break;
				case 0xA2: res4_r(d); break;
				case 0xA3: res4_r(e); break;
				case 0xA4: res4_r(h); break;
				case 0xA5: res4_r(l); break;
				case 0xA6: resn_mem_hl(4); break;
				case 0xA7: res4_r(a); break;

				case 0xA8: res5_r(b); break;
				case 0xA9: res5_r(c); break;
				case 0xAA: res5_r(d); break;
				case 0xAB: res5_r(e); break;
				case 0xAC: res5_r(h); break;
				case 0xAD: res5_r(l); break;
				case 0xAE: resn_mem_hl(5); break;
				case 0xAF: res5_r(a); break;

				case 0xB0: res6_r(b); break;
				case 0xB1: res6_r(c); break;
				case 0xB2: res6_r(d); break;
				case 0xB3: res6_r(e); break;
				case 0xB4: res6_r(h); break;
				case 0xB5: res6_r(l); break;
				case 0xB6: resn_mem_hl(6); break;
				case 0xB7: res6_r(a); break;

				case 0xB8: res7_r(b); break;
				case 0xB9: res7_r(c); break;
				case 0xBA: res7_r(d); break;
				case 0xBB: res7_r(e); break;
				case 0xBC: res7_r(h); break;
				case 0xBD: res7_r(l); break;
				case 0xBE: resn_mem_hl(7); break;
				case 0xBF: res7_r(a); break;

				case 0xC0: set0_r(b); break;
				case 0xC1: set0_r(c); break;
				case 0xC2: set0_r(d); break;
				case 0xC3: set0_r(e); break;
				case 0xC4: set0_r(h); break;
				case 0xC5: set0_r(l); break;
				case 0xC6: setn_mem_hl(0); break;
				case 0xC7: set0_r(a); break;

				case 0xC8: set1_r(b); break;
				case 0xC9: set1_r(c); break;
				case 0xCA: set1_r(d); break;
				case 0xCB: set1_r(e); break;
				case 0xCC: set1_r(h); break;
				case 0xCD: set1_r(l); break;
				case 0xCE: setn_mem_hl(1); break;
				case 0xCF: set1_r(a); break;

				case 0xD0: set2_r(b); break;
				case 0xD1: set2_r(c); break;
				case 0xD2: set2_r(d); break;
				case 0xD3: set2_r(e); break;
				case 0xD4: set2_r(h); break;
				case 0xD5: set2_r(l); break;
				case 0xD6: setn_mem_hl(2); break;
				case 0xD7: set2_r(a); break;

				case 0xD8: set3_r(b); break;
				case 0xD9: set3_r(c); break;
				case 0xDA: set3_r(d); break;
				case 0xDB: set3_r(e); break;
				case 0xDC: set3_r(h); break;
				case 0xDD: set3_r(l); break;
				case 0xDE: setn_mem_hl(3); break;
				case 0xDF: set3_r(a); break;

				case 0xE0: set4_r(b); break;
				case 0xE1: set4_r(c); break;
				case 0xE2: set4_r(d); break;
				case 0xE3: set4_r(e); break;
				case 0xE4: set4_r(h); break;
				case 0xE5: set4_r(l); break;
				case 0xE6: setn_mem_hl(4); break;
				case 0xE7: set4_r(a); break;

				case 0xE8: set5_r(b); break;
				case 0xE9: set5_r(c); break;
				case 0xEA: set5_r(d); break;
				case 0xEB: set5_r(e); break;
				case 0xEC: set5_r(h); break;
				case 0xED: set5_r(l); break;
				case 0xEE: setn_mem_hl(5); break;
				case 0xEF: set5_r(a); break;

				case 0xF0: set6_r(b); break;
				case 0xF1: set6_r(c); break;
				case 0xF2: set6_r(d); break;
				case 0xF3: set6_r(e); break;
				case 0xF4: set6_r(h); break;
				case 0xF5: set6_r(l); break;
				case 0xF6: setn_mem_hl(6); break;
				case 0xF7: set6_r(a); break;

				case 0xF8: set7_r(b); break;
				case 0xF9: set7_r(c); break;
				case 0xFA: set7_r(d); break;
				case 0xFB: set7_r(e); break;
				case 0xFC: set7_r(h); break;
				case 0xFD: set7_r(l); break;
				case 0xFE: setn_mem_hl(7); break;
				case 0xFF: set7_r(a); break;
				}

				break;


				// call z,nn (24;12 cycles):
				// Push address of next instruction onto stack and then jump to
				// address stored in next two bytes in memory, if ZF is set:
			case 0xCC:
				if (zf & 0xFF) {
					PC_MOD((pc + 2) & 0xFFFF);
					cycleCounter += 4;
				} else {
					call_nn();
				}

				break;

			case 0xCD:
				call_nn();
				break;

			case 0xCE:
				{
					unsigned data;
					PC_READ(data);
					adc_a_u8(data);
				}

				break;

			case 0xCF:
				rst_n(0x08);
				break;

				// ret nc (20;8 cycles):
				// Pop two bytes from the stack and jump to that address, if CF is unset:
			case 0xD0:
				cycleCounter += 4;

				if (!(cf & 0x100))
					ret();

				break;

			case 0xD1:
				pop_rr(d, e);
				break;

				// jp nc,nn (16;12 cycles):
				// Jump to address stored in next two bytes in memory if CF is unset:
			case 0xD2:
				if (cf & 0x100) {
					PC_MOD((pc + 2) & 0xFFFF);
					cycleCounter += 4;
				} else {
					jp_nn();
				}

				break;

			case 0xD3: // not specified. should freeze.
				break;

				// call nc,nn (24;12 cycles):
				// Push address of next instruction onto stack and then jump to
				// address stored in next two bytes in memory, if CF is unset:
			case 0xD4:
				if (cf & 0x100) {
					PC_MOD((pc + 2) & 0xFFFF);
					cycleCounter += 4;
				} else {
					call_nn();
				}

				break;

			case 0xD5:
				push_rr(d, e);
				break;

			case 0xD6:
				{
					unsigned data;
					PC_READ(data);
					sub_a_u8(data);
				}

				break;

			case 0xD7:
				rst_n(0x10);
				break;

				// ret c (20;8 cycles):
				// Pop two bytes from the stack and jump to that address, if CF is set:
			case 0xD8:
				cycleCounter += 4;

				if (cf & 0x100)
					ret();

				break;

				// reti (16 cycles):
				// Pop two bytes from the stack and jump to that address, then enable interrupts:
			case 0xD9:
				{
					unsigned sl, sh;
					pop_rr(sh, sl);
					mem_.ei(cycleCounter);
					PC_MOD(sh << 8 | sl);
				}

				break;

				// jp c,nn (16;12 cycles):
				// Jump to address stored in next two bytes in memory if CF is set:
			case 0xDA:
				if (cf & 0x100) {
					jp_nn();
				} else {
					PC_MOD((pc + 2) & 0xFFFF);
					cycleCounter += 4;
				}

				break;

			case 0xDB: // not specified. should freeze.
				break;

				// call z,nn (24;12 cycles):
				// Push address of next instruction onto stack and then jump to
				// address stored in next two bytes in memory, if CF is set:
			case 0xDC:
				if (cf & 0x100) {
					call_nn();
				} else {
					PC_MOD((pc + 2) & 0xFFFF);
					cycleCounter += 4;
				}

				break;

			case 0xDE:
				{
					unsigned data;
					PC_READ(data);
					sbc_a_u8(data);
				}

				break;

			case 0xDF:
				rst_n(0x18);
				break;

				// ld ($FF00+n),a (12 cycles):
				// Put value in A into address (0xFF00 + next byte in memory):
			case 0xE0:
				{
					unsigned imm;
					PC_READ(imm);
					FF_WRITE(imm, a);
				}

				break;

			case 0xE1:
				pop_rr(h, l);
				break;

				// ld ($FF00+C),a (8 ycles):
				// Put A into address (0xFF00 + register C):
			case 0xE2:
				FF_WRITE(c, a);
				break;

			case 0xE3: // not specified. should freeze.
				break;
			case 0xE4: // not specified. should freeze.
				break;

			case 0xE5:
				push_rr(h, l);
				break;

			case 0xE6:
				{
					unsigned data;
					PC_READ(data);
					and_a_u8(data);
				}

				break;

			case 0xE7:
				rst_n(0x20);
				break;

				// add sp,n (16 cycles):
				// Add next (signed) byte in memory to SP, reset ZF and SF, check HCF and CF:
			case 0xE8:
				sp_plus_n(sp);
				cycleCounter += 4;
				break;

				// jp hl (4 cycles):
				// Jump to address in hl:
			case 0xE9:
				pc = hl();
				break;

				// ld (nn),a (16 cycles):
				// set memory at address given by the next 2 bytes to value in A:
				// Incrementing PC before call, because of possible interrupt.
			case 0xEA:
				{
					unsigned imml, immh;
					PC_READ(imml);
					PC_READ(immh);
					WRITE(immh << 8 | imml, a);
				}

				break;

			case 0xEB: // not specified. should freeze.
				break;
			case 0xEC: // not specified. should freeze.
				break;
			case 0xED: // not specified. should freeze.
				break;

			case 0xEE:
				{
					unsigned data;
					PC_READ(data);
					xor_a_u8(data);
				}

				break;

			case 0xEF:
				rst_n(0x28);
				break;

				// ld a,($FF00+n) (12 cycles):
				// Put value at address (0xFF00 + next byte in memory) into A:
			case 0xF0:
				{
					unsigned imm;
					PC_READ(imm);
					FF_READ(a, imm);
				}

				break;

			case 0xF1:
				{
					unsigned F;
					pop_rr(a, F);
					zf  =  zfFromF(F);
					hf2 = hf2FromF(F);
					cf  =  cfFromF(F);
				}

				break;

				// ld a,($FF00+C) (8 cycles):
				// Put value at address (0xFF00 + register C) into A:
			case 0xF2:
				FF_READ(a, c);
				break;

				// di (4 cycles):
			case 0xF3:
				mem_.di();
				break;

			case 0xF4: // not specified. should freeze.
				break;

			case 0xF5:
				hf2 = updateHf2FromHf1(hf1, hf2);

				{
					unsigned F = toF(hf2, cf, zf);
					push_rr(a, F);
				}

				break;

			case 0xF6:
				{
					unsigned data;
					PC_READ(data);
					or_a_u8(data);
				}

				break;

			case 0xF7:
				rst_n(0x30);
				break;

				// ldhl sp,n (12 cycles):
				// Put (sp+next (signed) byte in memory) into hl (unsets ZF and SF, may enable HF and CF):
			case 0xF8:
				{
					unsigned sum;
					sp_plus_n(sum);
					l = sum & 0xFF;
					h = sum >> 8;
				}

				break;

				// ld sp,hl (8 cycles):
				// Put value in HL into SP
			case 0xF9:
				sp = hl();
				cycleCounter += 4;
				break;

				// ld a,(nn) (16 cycles):
				// set A to value in memory at address given by the 2 next bytes.
			case 0xFA:
				{
					unsigned imml, immh;
					PC_READ(imml);
					PC_READ(immh);

					READ(a, immh << 8 | imml);
				}

				break;

				// ei (4 cycles):
				// Enable Interrupts after next instruction:
			case 0xFB:
				mem_.ei(cycleCounter);
				break;

			case 0xFC: // not specified. should freeze.
				break;
			case 0xFD: // not specified. should freeze
				break;
			case 0xFE:
				{
					unsigned data;
					PC_READ(data);

					cp_a_u8(data);
				}

				break;

			case 0xFF:
				rst_n(0x38);
				break;
			}
		}

		pc_ = pc;
		cycleCounter = mem_.event(cycleCounter);
	}

	a_ = a;
	cycleCounter_ = cycleCounter;
}

}
