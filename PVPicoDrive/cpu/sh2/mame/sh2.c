/*****************************************************************************
 *
 *   sh2.c
 *   Portable Hitachi SH-2 (SH7600 family) emulator
 *
 *   Copyright Juergen Buchmueller <pullmoll@t-online.de>,
 *   all rights reserved.
 *
 *   - This source code is released as freeware for non-commercial purposes.
 *   - You are free to use and redistribute this code in modified or
 *     unmodified form, provided you list me in the credits.
 *   - If you modify this source code, you must add a notice to each modified
 *     source file that it has been changed.  If you're a nice person, you
 *     will clearly mark each change too.  :)
 *   - If you wish to use this for commercial purposes, please contact me at
 *     pullmoll@t-online.de
 *   - The author of this copywritten work reserves the right to change the
 *     terms of its usage and license at any time, including retroactively
 *   - This entire notice must remain in the source code.
 *
 *  This work is based on <tiraniddo@hotmail.com> C/C++ implementation of
 *  the SH-2 CPU core and was adapted to the MAME CPU core requirements.
 *  Thanks also go to Chuck Mason <chukjr@sundail.net> and Olivier Galibert
 *  <galibert@pobox.com> for letting me peek into their SEMU code :-)
 *
 *****************************************************************************/

/*****************************************************************************
    Changes
    20130129 Angelo Salese
    - added illegal opcode exception handling, side effect of some Saturn games
      on loading like Feda or Falcom Classics Vol. 1
      (i.e. Master CPU Incautiously transfers memory from CD to work RAM H, and
            wipes out Slave CPU program code too while at it).

    20051129 Mariusz Wojcieszek
    - introduced memory_decrypted_read_word() for opcode fetching

    20050813 Mariusz Wojcieszek
    - fixed 64 bit / 32 bit division in division unit

    20031015 O. Galibert
    - dma fixes, thanks to sthief

    20031013 O. Galibert, A. Giles
    - timer fixes
    - multi-cpu simplifications

    20030915 O. Galibert
    - fix DMA1 irq vector
    - ignore writes to DRCRx
    - fix cpu number issues
    - fix slave/master recognition
    - fix wrong-cpu-in-context problem with the timers

    20021020 O. Galibert
    - DMA implementation, lightly tested
    - delay slot in debugger fixed
    - add divide box mirrors
    - Nicola-ify the indentation
    - Uncrapify sh2_internal_*
    - Put back nmi support that had been lost somehow

    20020914 R. Belmont
    - Initial SH2 internal timers implementation, based on code by O. Galibert.
      Makes music work in galspanic4/s/s2, panic street, cyvern, other SKNS games.
    - Fix to external division, thanks to "spice" on the E2J board.
      Corrects behavior of s1945ii turret boss.

    20020302 Olivier Galibert (galibert@mame.net)
    - Fixed interrupt in delay slot
    - Fixed rotcr
    - Fixed div1
    - Fixed mulu
    - Fixed negc

    20020301 R. Belmont
    - Fixed external division

    20020225 Olivier Galibert (galibert@mame.net)
    - Fixed interrupt handling

    20010207 Sylvain Glaize (mokona@puupuu.org)

    - Bug fix in INLINE void MOVBM(UINT32 m, UINT32 n) (see comment)
    - Support of full 32 bit addressing (RB, RW, RL and WB, WW, WL functions)
        reason : when the two high bits of the address are set, access is
        done directly in the cache data array. The SUPER KANEKO NOVA SYSTEM
        sets the stack pointer here, using these addresses as usual RAM access.

        No real cache support has been added.
    - Read/Write memory format correction (_bew to _bedw) (see also SH2
        definition in cpuintrf.c and DasmSH2(..) in sh2dasm.c )

    20010623 James Forshaw (TyRaNiD@totalise.net)

    - Modified operation of sh2_exception. Done cause mame irq system is stupid, and
      doesnt really seem designed for any more than 8 interrupt lines.

    20010701 James Forshaw (TyRaNiD@totalise.net)

    - Fixed DIV1 operation. Q bit now correctly generated

    20020218 Added save states (mokona@puupuu.org)

 *****************************************************************************/

//#include "debugger.h"
//#include "sh2.h"
//#include "sh2comn.h"
#define INLINE static

//CPU_DISASSEMBLE( sh2 );

#ifndef USE_SH2DRC

/* speed up delay loops, bail out of tight loops */
//#define BUSY_LOOP_HACKS 	1

#define VERBOSE 0

#define LOG(x)	do { if (VERBOSE) logerror x; } while (0)

#if 0
INLINE UINT8 RB(sh2_state *sh2, offs_t A)
{
	if (A >= 0xe0000000)
		return sh2_internal_r(*sh2->internal, (A & 0x1fc)>>2, 0xff << (((~A) & 3)*8)) >> (((~A) & 3)*8);

	if (A >= 0xc0000000)
		return sh2->program->read_byte(A);

	if (A >= 0x40000000)
		return 0xa5;

	return sh2->program->read_byte(A & AM);
}

INLINE UINT16 RW(sh2_state *sh2, offs_t A)
{
	if (A >= 0xe0000000)
		return sh2_internal_r(*sh2->internal, (A & 0x1fc)>>2, 0xffff << (((~A) & 2)*8)) >> (((~A) & 2)*8);

	if (A >= 0xc0000000)
		return sh2->program->read_word(A);

	if (A >= 0x40000000)
		return 0xa5a5;

	return sh2->program->read_word(A & AM);
}

INLINE UINT32 RL(sh2_state *sh2, offs_t A)
{
	if (A >= 0xe0000000)
		return sh2_internal_r(*sh2->internal, (A & 0x1fc)>>2, 0xffffffff);

	if (A >= 0xc0000000)
		return sh2->program->read_dword(A);

	if (A >= 0x40000000)
		return 0xa5a5a5a5;

	return sh2->program->read_dword(A & AM);
}

INLINE void WB(sh2_state *sh2, offs_t A, UINT8 V)
{
	if (A >= 0xe0000000)
	{
		sh2_internal_w(*sh2->internal, (A & 0x1fc)>>2, V << (((~A) & 3)*8), 0xff << (((~A) & 3)*8));
		return;
	}

	if (A >= 0xc0000000)
	{
		sh2->program->write_byte(A,V);
		return;
	}

	if (A >= 0x40000000)
		return;

	sh2->program->write_byte(A & AM,V);
}

INLINE void WW(sh2_state *sh2, offs_t A, UINT16 V)
{
	if (A >= 0xe0000000)
	{
		sh2_internal_w(*sh2->internal, (A & 0x1fc)>>2, V << (((~A) & 2)*8), 0xffff << (((~A) & 2)*8));
		return;
	}

	if (A >= 0xc0000000)
	{
		sh2->program->write_word(A,V);
		return;
	}

	if (A >= 0x40000000)
		return;

	sh2->program->write_word(A & AM,V);
}

INLINE void WL(sh2_state *sh2, offs_t A, UINT32 V)
{
	if (A >= 0xe0000000)
	{
		sh2_internal_w(*sh2->internal, (A & 0x1fc)>>2, V, 0xffffffff);
		return;
	}

	if (A >= 0xc0000000)
	{
		sh2->program->write_dword(A,V);
		return;
	}

	if (A >= 0x40000000)
		return;

	sh2->program->write_dword(A & AM,V);
}
#endif

/*  code                 cycles  t-bit
 *  0011 nnnn mmmm 1100  1       -
 *  ADD     Rm,Rn
 */
INLINE void ADD(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->r[n] += sh2->r[m];
}

/*  code                 cycles  t-bit
 *  0111 nnnn iiii iiii  1       -
 *  ADD     #imm,Rn
 */
INLINE void ADDI(sh2_state *sh2, UINT32 i, UINT32 n)
{
	sh2->r[n] += (INT32)(INT16)(INT8)i;
}

/*  code                 cycles  t-bit
 *  0011 nnnn mmmm 1110  1       carry
 *  ADDC    Rm,Rn
 */
INLINE void ADDC(sh2_state *sh2, UINT32 m, UINT32 n)
{
	UINT32 tmp0, tmp1;

	tmp1 = sh2->r[n] + sh2->r[m];
	tmp0 = sh2->r[n];
	sh2->r[n] = tmp1 + (sh2->sr & T);
	if (tmp0 > tmp1)
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
	if (tmp1 > sh2->r[n])
		sh2->sr |= T;
}

/*  code                 cycles  t-bit
 *  0011 nnnn mmmm 1111  1       overflow
 *  ADDV    Rm,Rn
 */
INLINE void ADDV(sh2_state *sh2, UINT32 m, UINT32 n)
{
	INT32 dest, src, ans;

	if ((INT32) sh2->r[n] >= 0)
		dest = 0;
	else
		dest = 1;
	if ((INT32) sh2->r[m] >= 0)
		src = 0;
	else
		src = 1;
	src += dest;
	sh2->r[n] += sh2->r[m];
	if ((INT32) sh2->r[n] >= 0)
		ans = 0;
	else
		ans = 1;
	ans += dest;
	if (src == 0 || src == 2)
	{
		if (ans == 1)
			sh2->sr |= T;
		else
			sh2->sr &= ~T;
	}
	else
		sh2->sr &= ~T;
}

/*  code                 cycles  t-bit
 *  0010 nnnn mmmm 1001  1       -
 *  AND     Rm,Rn
 */
INLINE void AND(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->r[n] &= sh2->r[m];
}


/*  code                 cycles  t-bit
 *  1100 1001 iiii iiii  1       -
 *  AND     #imm,R0
 */
INLINE void ANDI(sh2_state *sh2, UINT32 i)
{
	sh2->r[0] &= i;
}

/*  code                 cycles  t-bit
 *  1100 1101 iiii iiii  1       -
 *  AND.B   #imm,@(R0,GBR)
 */
INLINE void ANDM(sh2_state *sh2, UINT32 i)
{
	UINT32 temp;

	sh2->ea = sh2->gbr + sh2->r[0];
	temp = i & RB( sh2, sh2->ea );
	WB( sh2, sh2->ea, temp );
	sh2->icount -= 2;
}

/*  code                 cycles  t-bit
 *  1000 1011 dddd dddd  3/1     -
 *  BF      disp8
 */
INLINE void BF(sh2_state *sh2, UINT32 d)
{
	if ((sh2->sr & T) == 0)
	{
		INT32 disp = ((INT32)d << 24) >> 24;
		sh2->pc = sh2->ea = sh2->pc + disp * 2 + 2;
		sh2->icount -= 2;
	}
}

/*  code                 cycles  t-bit
 *  1000 1111 dddd dddd  3/1     -
 *  BFS     disp8
 */
INLINE void BFS(sh2_state *sh2, UINT32 d)
{
	sh2->delay = sh2->pc;
	sh2->pc += 2;

	if ((sh2->sr & T) == 0)
	{
		INT32 disp = ((INT32)d << 24) >> 24;
		sh2->pc = sh2->ea = sh2->pc + disp * 2;
		sh2->icount--;
	}
}

/*  code                 cycles  t-bit
 *  1010 dddd dddd dddd  2       -
 *  BRA     disp12
 */
INLINE void BRA(sh2_state *sh2, UINT32 d)
{
	INT32 disp = ((INT32)d << 20) >> 20;

#if BUSY_LOOP_HACKS
	if (disp == -2)
	{
		UINT32 next_opcode = RW( sh2, sh2->ppc & AM );
		/* BRA  $
		 * NOP
		 */
		if (next_opcode == 0x0009)
			sh2->icount %= 3;   /* cycles for BRA $ and NOP taken (3) */
	}
#endif
	sh2->delay = sh2->pc;
	sh2->pc = sh2->ea = sh2->pc + disp * 2 + 2;
	sh2->icount--;
}

/*  code                 cycles  t-bit
 *  0000 mmmm 0010 0011  2       -
 *  BRAF    Rm
 */
INLINE void BRAF(sh2_state *sh2, UINT32 m)
{
	sh2->delay = sh2->pc;
	sh2->pc += sh2->r[m] + 2;
	sh2->icount--;
}

/*  code                 cycles  t-bit
 *  1011 dddd dddd dddd  2       -
 *  BSR     disp12
 */
INLINE void BSR(sh2_state *sh2, UINT32 d)
{
	INT32 disp = ((INT32)d << 20) >> 20;

	sh2->pr = sh2->pc + 2;
	sh2->delay = sh2->pc;
	sh2->pc = sh2->ea = sh2->pc + disp * 2 + 2;
	sh2->icount--;
}

/*  code                 cycles  t-bit
 *  0000 mmmm 0000 0011  2       -
 *  BSRF    Rm
 */
INLINE void BSRF(sh2_state *sh2, UINT32 m)
{
	sh2->pr = sh2->pc + 2;
	sh2->delay = sh2->pc;
	sh2->pc += sh2->r[m] + 2;
	sh2->icount--;
}

/*  code                 cycles  t-bit
 *  1000 1001 dddd dddd  3/1     -
 *  BT      disp8
 */
INLINE void BT(sh2_state *sh2, UINT32 d)
{
	if ((sh2->sr & T) != 0)
	{
		INT32 disp = ((INT32)d << 24) >> 24;
		sh2->pc = sh2->ea = sh2->pc + disp * 2 + 2;
		sh2->icount -= 2;
	}
}

/*  code                 cycles  t-bit
 *  1000 1101 dddd dddd  2/1     -
 *  BTS     disp8
 */
INLINE void BTS(sh2_state *sh2, UINT32 d)
{
	sh2->delay = sh2->pc;
	sh2->pc += 2;

	if ((sh2->sr & T) != 0)
	{
		INT32 disp = ((INT32)d << 24) >> 24;
		sh2->pc = sh2->ea = sh2->pc + disp * 2;
		sh2->icount--;
	}
}

/*  code                 cycles  t-bit
 *  0000 0000 0010 1000  1       -
 *  CLRMAC
 */
INLINE void CLRMAC(sh2_state *sh2)
{
	sh2->mach = 0;
	sh2->macl = 0;
}

/*  code                 cycles  t-bit
 *  0000 0000 0000 1000  1       -
 *  CLRT
 */
INLINE void CLRT(sh2_state *sh2)
{
	sh2->sr &= ~T;
}

/*  code                 cycles  t-bit
 *  0011 nnnn mmmm 0000  1       comparison result
 *  CMP_EQ  Rm,Rn
 */
INLINE void CMPEQ(sh2_state *sh2, UINT32 m, UINT32 n)
{
	if (sh2->r[n] == sh2->r[m])
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
}

/*  code                 cycles  t-bit
 *  0011 nnnn mmmm 0011  1       comparison result
 *  CMP_GE  Rm,Rn
 */
INLINE void CMPGE(sh2_state *sh2, UINT32 m, UINT32 n)
{
	if ((INT32) sh2->r[n] >= (INT32) sh2->r[m])
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
}

/*  code                 cycles  t-bit
 *  0011 nnnn mmmm 0111  1       comparison result
 *  CMP_GT  Rm,Rn
 */
INLINE void CMPGT(sh2_state *sh2, UINT32 m, UINT32 n)
{
	if ((INT32) sh2->r[n] > (INT32) sh2->r[m])
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
}

/*  code                 cycles  t-bit
 *  0011 nnnn mmmm 0110  1       comparison result
 *  CMP_HI  Rm,Rn
 */
INLINE void CMPHI(sh2_state *sh2, UINT32 m, UINT32 n)
{
	if ((UINT32) sh2->r[n] > (UINT32) sh2->r[m])
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
}

/*  code                 cycles  t-bit
 *  0011 nnnn mmmm 0010  1       comparison result
 *  CMP_HS  Rm,Rn
 */
INLINE void CMPHS(sh2_state *sh2, UINT32 m, UINT32 n)
{
	if ((UINT32) sh2->r[n] >= (UINT32) sh2->r[m])
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
}


/*  code                 cycles  t-bit
 *  0100 nnnn 0001 0101  1       comparison result
 *  CMP_PL  Rn
 */
INLINE void CMPPL(sh2_state *sh2, UINT32 n)
{
	if ((INT32) sh2->r[n] > 0)
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
}

/*  code                 cycles  t-bit
 *  0100 nnnn 0001 0001  1       comparison result
 *  CMP_PZ  Rn
 */
INLINE void CMPPZ(sh2_state *sh2, UINT32 n)
{
	if ((INT32) sh2->r[n] >= 0)
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
}

/*  code                 cycles  t-bit
 *  0010 nnnn mmmm 1100  1       comparison result
 * CMP_STR  Rm,Rn
 */
INLINE void CMPSTR(sh2_state *sh2, UINT32 m, UINT32 n)
	{
	UINT32 temp;
	INT32 HH, HL, LH, LL;
	temp = sh2->r[n] ^ sh2->r[m];
	HH = (temp >> 24) & 0xff;
	HL = (temp >> 16) & 0xff;
	LH = (temp >> 8) & 0xff;
	LL = temp & 0xff;
	if (HH && HL && LH && LL)
	sh2->sr &= ~T;
	else
	sh2->sr |= T;
	}


/*  code                 cycles  t-bit
 *  1000 1000 iiii iiii  1       comparison result
 *  CMP/EQ #imm,R0
 */
INLINE void CMPIM(sh2_state *sh2, UINT32 i)
{
	UINT32 imm = (UINT32)(INT32)(INT16)(INT8)i;

	if (sh2->r[0] == imm)
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
}

/*  code                 cycles  t-bit
 *  0010 nnnn mmmm 0111  1       calculation result
 *  DIV0S   Rm,Rn
 */
INLINE void DIV0S(sh2_state *sh2, UINT32 m, UINT32 n)
{
	if ((sh2->r[n] & 0x80000000) == 0)
		sh2->sr &= ~Q;
	else
		sh2->sr |= Q;
	if ((sh2->r[m] & 0x80000000) == 0)
		sh2->sr &= ~M;
	else
		sh2->sr |= M;
	if ((sh2->r[m] ^ sh2->r[n]) & 0x80000000)
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
}

/*  code                 cycles  t-bit
 *  0000 0000 0001 1001  1       0
 *  DIV0U
 */
INLINE void DIV0U(sh2_state *sh2)
{
	sh2->sr &= ~(M | Q | T);
}

/*  code                 cycles  t-bit
 *  0011 nnnn mmmm 0100  1       calculation result
 *  DIV1 Rm,Rn
 */
INLINE void DIV1(sh2_state *sh2, UINT32 m, UINT32 n)
{
	UINT32 tmp0;
	UINT32 old_q;

	old_q = sh2->sr & Q;
	if (0x80000000 & sh2->r[n])
		sh2->sr |= Q;
	else
		sh2->sr &= ~Q;

	sh2->r[n] = (sh2->r[n] << 1) | (sh2->sr & T);

	if (!old_q)
	{
		if (!(sh2->sr & M))
		{
			tmp0 = sh2->r[n];
			sh2->r[n] -= sh2->r[m];
			if(!(sh2->sr & Q))
				if(sh2->r[n] > tmp0)
					sh2->sr |= Q;
				else
					sh2->sr &= ~Q;
			else
				if(sh2->r[n] > tmp0)
					sh2->sr &= ~Q;
				else
					sh2->sr |= Q;
		}
		else
		{
			tmp0 = sh2->r[n];
			sh2->r[n] += sh2->r[m];
			if(!(sh2->sr & Q))
			{
				if(sh2->r[n] < tmp0)
					sh2->sr &= ~Q;
				else
					sh2->sr |= Q;
			}
			else
			{
				if(sh2->r[n] < tmp0)
					sh2->sr |= Q;
				else
					sh2->sr &= ~Q;
			}
		}
	}
	else
	{
		if (!(sh2->sr & M))
		{
			tmp0 = sh2->r[n];
			sh2->r[n] += sh2->r[m];
			if(!(sh2->sr & Q))
				if(sh2->r[n] < tmp0)
					sh2->sr |= Q;
				else
					sh2->sr &= ~Q;
			else
				if(sh2->r[n] < tmp0)
					sh2->sr &= ~Q;
				else
					sh2->sr |= Q;
		}
		else
		{
			tmp0 = sh2->r[n];
			sh2->r[n] -= sh2->r[m];
			if(!(sh2->sr & Q))
				if(sh2->r[n] > tmp0)
					sh2->sr &= ~Q;
				else
					sh2->sr |= Q;
			else
				if(sh2->r[n] > tmp0)
					sh2->sr |= Q;
				else
					sh2->sr &= ~Q;
		}
	}

	tmp0 = (sh2->sr & (Q | M));
	if((!tmp0) || (tmp0 == 0x300)) /* if Q == M set T else clear T */
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
}

/*  DMULS.L Rm,Rn */
INLINE void DMULS(sh2_state *sh2, UINT32 m, UINT32 n)
{
	UINT32 RnL, RnH, RmL, RmH, Res0, Res1, Res2;
	UINT32 temp0, temp1, temp2, temp3;
	INT32 tempm, tempn, fnLmL;

	tempn = (INT32) sh2->r[n];
	tempm = (INT32) sh2->r[m];
	if (tempn < 0)
		tempn = 0 - tempn;
	if (tempm < 0)
		tempm = 0 - tempm;
	if ((INT32) (sh2->r[n] ^ sh2->r[m]) < 0)
		fnLmL = -1;
	else
		fnLmL = 0;
	temp1 = (UINT32) tempn;
	temp2 = (UINT32) tempm;
	RnL = temp1 & 0x0000ffff;
	RnH = (temp1 >> 16) & 0x0000ffff;
	RmL = temp2 & 0x0000ffff;
	RmH = (temp2 >> 16) & 0x0000ffff;
	temp0 = RmL * RnL;
	temp1 = RmH * RnL;
	temp2 = RmL * RnH;
	temp3 = RmH * RnH;
	Res2 = 0;
	Res1 = temp1 + temp2;
	if (Res1 < temp1)
		Res2 += 0x00010000;
	temp1 = (Res1 << 16) & 0xffff0000;
	Res0 = temp0 + temp1;
	if (Res0 < temp0)
		Res2++;
	Res2 = Res2 + ((Res1 >> 16) & 0x0000ffff) + temp3;
	if (fnLmL < 0)
	{
		Res2 = ~Res2;
		if (Res0 == 0)
			Res2++;
		else
			Res0 = (~Res0) + 1;
	}
	sh2->mach = Res2;
	sh2->macl = Res0;
	sh2->icount--;
}

/*  DMULU.L Rm,Rn */
INLINE void DMULU(sh2_state *sh2, UINT32 m, UINT32 n)
{
	UINT32 RnL, RnH, RmL, RmH, Res0, Res1, Res2;
	UINT32 temp0, temp1, temp2, temp3;

	RnL = sh2->r[n] & 0x0000ffff;
	RnH = (sh2->r[n] >> 16) & 0x0000ffff;
	RmL = sh2->r[m] & 0x0000ffff;
	RmH = (sh2->r[m] >> 16) & 0x0000ffff;
	temp0 = RmL * RnL;
	temp1 = RmH * RnL;
	temp2 = RmL * RnH;
	temp3 = RmH * RnH;
	Res2 = 0;
	Res1 = temp1 + temp2;
	if (Res1 < temp1)
		Res2 += 0x00010000;
	temp1 = (Res1 << 16) & 0xffff0000;
	Res0 = temp0 + temp1;
	if (Res0 < temp0)
		Res2++;
	Res2 = Res2 + ((Res1 >> 16) & 0x0000ffff) + temp3;
	sh2->mach = Res2;
	sh2->macl = Res0;
	sh2->icount--;
}

/*  DT      Rn */
INLINE void DT(sh2_state *sh2, UINT32 n)
{
	sh2->r[n]--;
	if (sh2->r[n] == 0)
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
#if BUSY_LOOP_HACKS
	{
		UINT32 next_opcode = RW( sh2, sh2->ppc & AM );
		/* DT   Rn
		 * BF   $-2
		 */
		if (next_opcode == 0x8bfd)
		{
			while (sh2->r[n] > 1 && sh2->icount > 4)
			{
				sh2->r[n]--;
				sh2->icount -= 4;   /* cycles for DT (1) and BF taken (3) */
			}
		}
	}
#endif
}

/*  EXTS.B  Rm,Rn */
INLINE void EXTSB(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->r[n] = ((INT32)sh2->r[m] << 24) >> 24;
}

/*  EXTS.W  Rm,Rn */
INLINE void EXTSW(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->r[n] = ((INT32)sh2->r[m] << 16) >> 16;
}

/*  EXTU.B  Rm,Rn */
INLINE void EXTUB(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->r[n] = sh2->r[m] & 0x000000ff;
}

/*  EXTU.W  Rm,Rn */
INLINE void EXTUW(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->r[n] = sh2->r[m] & 0x0000ffff;
}

/*  ILLEGAL */
INLINE void ILLEGAL(sh2_state *sh2)
{
	logerror("SH2: Illegal opcode at %08x\n", sh2->pc - 2);
	sh2->r[15] -= 4;
	WL( sh2, sh2->r[15], sh2->sr );     /* push SR onto stack */
	sh2->r[15] -= 4;
	WL( sh2, sh2->r[15], sh2->pc - 2 ); /* push PC onto stack */

	/* fetch PC */
	sh2->pc = RL( sh2, sh2->vbr + 4 * 4 );

	/* TODO: timing is a guess */
	sh2->icount -= 5;
}


/*  JMP     @Rm */
INLINE void JMP(sh2_state *sh2, UINT32 m)
{
	sh2->delay = sh2->pc;
	sh2->pc = sh2->ea = sh2->r[m];
	sh2->icount--;
}

/*  JSR     @Rm */
INLINE void JSR(sh2_state *sh2, UINT32 m)
{
	sh2->delay = sh2->pc;
	sh2->pr = sh2->pc + 2;
	sh2->pc = sh2->ea = sh2->r[m];
	sh2->icount--;
}


/*  LDC     Rm,SR */
INLINE void LDCSR(sh2_state *sh2, UINT32 m)
{
	sh2->sr = sh2->r[m] & FLAGS;
	sh2->test_irq = 1;
}

/*  LDC     Rm,GBR */
INLINE void LDCGBR(sh2_state *sh2, UINT32 m)
{
	sh2->gbr = sh2->r[m];
}

/*  LDC     Rm,VBR */
INLINE void LDCVBR(sh2_state *sh2, UINT32 m)
{
	sh2->vbr = sh2->r[m];
}

/*  LDC.L   @Rm+,SR */
INLINE void LDCMSR(sh2_state *sh2, UINT32 m)
{
	sh2->ea = sh2->r[m];
	sh2->sr = RL( sh2, sh2->ea ) & FLAGS;
	sh2->r[m] += 4;
	sh2->icount -= 2;
	sh2->test_irq = 1;
}

/*  LDC.L   @Rm+,GBR */
INLINE void LDCMGBR(sh2_state *sh2, UINT32 m)
{
	sh2->ea = sh2->r[m];
	sh2->gbr = RL( sh2, sh2->ea );
	sh2->r[m] += 4;
	sh2->icount -= 2;
}

/*  LDC.L   @Rm+,VBR */
INLINE void LDCMVBR(sh2_state *sh2, UINT32 m)
{
	sh2->ea = sh2->r[m];
	sh2->vbr = RL( sh2, sh2->ea );
	sh2->r[m] += 4;
	sh2->icount -= 2;
}

/*  LDS     Rm,MACH */
INLINE void LDSMACH(sh2_state *sh2, UINT32 m)
{
	sh2->mach = sh2->r[m];
}

/*  LDS     Rm,MACL */
INLINE void LDSMACL(sh2_state *sh2, UINT32 m)
{
	sh2->macl = sh2->r[m];
}

/*  LDS     Rm,PR */
INLINE void LDSPR(sh2_state *sh2, UINT32 m)
{
	sh2->pr = sh2->r[m];
}

/*  LDS.L   @Rm+,MACH */
INLINE void LDSMMACH(sh2_state *sh2, UINT32 m)
{
	sh2->ea = sh2->r[m];
	sh2->mach = RL( sh2, sh2->ea );
	sh2->r[m] += 4;
}

/*  LDS.L   @Rm+,MACL */
INLINE void LDSMMACL(sh2_state *sh2, UINT32 m)
{
	sh2->ea = sh2->r[m];
	sh2->macl = RL( sh2, sh2->ea );
	sh2->r[m] += 4;
}

/*  LDS.L   @Rm+,PR */
INLINE void LDSMPR(sh2_state *sh2, UINT32 m)
{
	sh2->ea = sh2->r[m];
	sh2->pr = RL( sh2, sh2->ea );
	sh2->r[m] += 4;
}

/*  MAC.L   @Rm+,@Rn+ */
INLINE void MAC_L(sh2_state *sh2, UINT32 m, UINT32 n)
{
	UINT32 RnL, RnH, RmL, RmH, Res0, Res1, Res2;
	UINT32 temp0, temp1, temp2, temp3;
	INT32 tempm, tempn, fnLmL;

	tempn = (INT32) RL( sh2, sh2->r[n] );
	sh2->r[n] += 4;
	tempm = (INT32) RL( sh2, sh2->r[m] );
	sh2->r[m] += 4;
	if ((INT32) (tempn ^ tempm) < 0)
		fnLmL = -1;
	else
		fnLmL = 0;
	if (tempn < 0)
		tempn = 0 - tempn;
	if (tempm < 0)
		tempm = 0 - tempm;
	temp1 = (UINT32) tempn;
	temp2 = (UINT32) tempm;
	RnL = temp1 & 0x0000ffff;
	RnH = (temp1 >> 16) & 0x0000ffff;
	RmL = temp2 & 0x0000ffff;
	RmH = (temp2 >> 16) & 0x0000ffff;
	temp0 = RmL * RnL;
	temp1 = RmH * RnL;
	temp2 = RmL * RnH;
	temp3 = RmH * RnH;
	Res2 = 0;
	Res1 = temp1 + temp2;
	if (Res1 < temp1)
		Res2 += 0x00010000;
	temp1 = (Res1 << 16) & 0xffff0000;
	Res0 = temp0 + temp1;
	if (Res0 < temp0)
		Res2++;
	Res2 = Res2 + ((Res1 >> 16) & 0x0000ffff) + temp3;
	if (fnLmL < 0)
	{
		Res2 = ~Res2;
		if (Res0 == 0)
			Res2++;
		else
			Res0 = (~Res0) + 1;
	}
	if (sh2->sr & S)
	{
		Res0 = sh2->macl + Res0;
		if (sh2->macl > Res0)
			Res2++;
		Res2 += (sh2->mach & 0x0000ffff);
		if (((INT32) Res2 < 0) && (Res2 < 0xffff8000))
		{
			Res2 = 0x00008000;
			Res0 = 0x00000000;
		}
		else if (((INT32) Res2 > 0) && (Res2 > 0x00007fff))
		{
			Res2 = 0x00007fff;
			Res0 = 0xffffffff;
		}
		sh2->mach = Res2;
		sh2->macl = Res0;
	}
	else
	{
		Res0 = sh2->macl + Res0;
		if (sh2->macl > Res0)
			Res2++;
		Res2 += sh2->mach;
		sh2->mach = Res2;
		sh2->macl = Res0;
	}
	sh2->icount -= 2;
}

/*  MAC.W   @Rm+,@Rn+ */
INLINE void MAC_W(sh2_state *sh2, UINT32 m, UINT32 n)
{
	INT32 tempm, tempn, dest, src, ans;
	UINT32 templ;

	tempn = (INT32) RW( sh2, sh2->r[n] );
	sh2->r[n] += 2;
	tempm = (INT32) RW( sh2, sh2->r[m] );
	sh2->r[m] += 2;
	templ = sh2->macl;
	tempm = ((INT32) (short) tempn * (INT32) (short) tempm);
	if ((INT32) sh2->macl >= 0)
		dest = 0;
	else
		dest = 1;
	if ((INT32) tempm >= 0)
	{
		src = 0;
		tempn = 0;
	}
	else
	{
		src = 1;
		tempn = 0xffffffff;
	}
	src += dest;
	sh2->macl += tempm;
	if ((INT32) sh2->macl >= 0)
		ans = 0;
	else
		ans = 1;
	ans += dest;
	if (sh2->sr & S)
	{
		if (ans == 1)
			{
				if (src == 0)
					sh2->macl = 0x7fffffff;
				if (src == 2)
					sh2->macl = 0x80000000;
			}
	}
	else
	{
		sh2->mach += tempn;
		if (templ > sh2->macl)
			sh2->mach += 1;
	}
	sh2->icount -= 2;
}

/*  MOV     Rm,Rn */
INLINE void MOV(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->r[n] = sh2->r[m];
}

/*  MOV.B   Rm,@Rn */
INLINE void MOVBS(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->ea = sh2->r[n];
	WB( sh2, sh2->ea, sh2->r[m] & 0x000000ff);
}

/*  MOV.W   Rm,@Rn */
INLINE void MOVWS(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->ea = sh2->r[n];
	WW( sh2, sh2->ea, sh2->r[m] & 0x0000ffff);
}

/*  MOV.L   Rm,@Rn */
INLINE void MOVLS(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->ea = sh2->r[n];
	WL( sh2, sh2->ea, sh2->r[m] );
}

/*  MOV.B   @Rm,Rn */
INLINE void MOVBL(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->ea = sh2->r[m];
	sh2->r[n] = (UINT32)(INT32)(INT16)(INT8) RB( sh2, sh2->ea );
}

/*  MOV.W   @Rm,Rn */
INLINE void MOVWL(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->ea = sh2->r[m];
	sh2->r[n] = (UINT32)(INT32)(INT16) RW( sh2, sh2->ea );
}

/*  MOV.L   @Rm,Rn */
INLINE void MOVLL(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->ea = sh2->r[m];
	sh2->r[n] = RL( sh2, sh2->ea );
}

/*  MOV.B   Rm,@-Rn */
INLINE void MOVBM(sh2_state *sh2, UINT32 m, UINT32 n)
{
	/* SMG : bug fix, was reading sh2->r[n] */
	UINT32 data = sh2->r[m] & 0x000000ff;

	sh2->r[n] -= 1;
	WB( sh2, sh2->r[n], data );
}

/*  MOV.W   Rm,@-Rn */
INLINE void MOVWM(sh2_state *sh2, UINT32 m, UINT32 n)
{
	UINT32 data = sh2->r[m] & 0x0000ffff;

	sh2->r[n] -= 2;
	WW( sh2, sh2->r[n], data );
}

/*  MOV.L   Rm,@-Rn */
INLINE void MOVLM(sh2_state *sh2, UINT32 m, UINT32 n)
{
	UINT32 data = sh2->r[m];

	sh2->r[n] -= 4;
	WL( sh2, sh2->r[n], data );
}

/*  MOV.B   @Rm+,Rn */
INLINE void MOVBP(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->r[n] = (UINT32)(INT32)(INT16)(INT8) RB( sh2, sh2->r[m] );
	if (n != m)
		sh2->r[m] += 1;
}

/*  MOV.W   @Rm+,Rn */
INLINE void MOVWP(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->r[n] = (UINT32)(INT32)(INT16) RW( sh2, sh2->r[m] );
	if (n != m)
		sh2->r[m] += 2;
}

/*  MOV.L   @Rm+,Rn */
INLINE void MOVLP(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->r[n] = RL( sh2, sh2->r[m] );
	if (n != m)
		sh2->r[m] += 4;
}

/*  MOV.B   Rm,@(R0,Rn) */
INLINE void MOVBS0(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->ea = sh2->r[n] + sh2->r[0];
	WB( sh2, sh2->ea, sh2->r[m] & 0x000000ff );
}

/*  MOV.W   Rm,@(R0,Rn) */
INLINE void MOVWS0(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->ea = sh2->r[n] + sh2->r[0];
	WW( sh2, sh2->ea, sh2->r[m] & 0x0000ffff );
}

/*  MOV.L   Rm,@(R0,Rn) */
INLINE void MOVLS0(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->ea = sh2->r[n] + sh2->r[0];
	WL( sh2, sh2->ea, sh2->r[m] );
}

/*  MOV.B   @(R0,Rm),Rn */
INLINE void MOVBL0(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->ea = sh2->r[m] + sh2->r[0];
	sh2->r[n] = (UINT32)(INT32)(INT16)(INT8) RB( sh2, sh2->ea );
}

/*  MOV.W   @(R0,Rm),Rn */
INLINE void MOVWL0(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->ea = sh2->r[m] + sh2->r[0];
	sh2->r[n] = (UINT32)(INT32)(INT16) RW( sh2, sh2->ea );
}

/*  MOV.L   @(R0,Rm),Rn */
INLINE void MOVLL0(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->ea = sh2->r[m] + sh2->r[0];
	sh2->r[n] = RL( sh2, sh2->ea );
}

/*  MOV     #imm,Rn */
INLINE void MOVI(sh2_state *sh2, UINT32 i, UINT32 n)
{
	sh2->r[n] = (UINT32)(INT32)(INT16)(INT8) i;
}

/*  MOV.W   @(disp8,PC),Rn */
INLINE void MOVWI(sh2_state *sh2, UINT32 d, UINT32 n)
{
	UINT32 disp = d & 0xff;
	sh2->ea = sh2->pc + disp * 2 + 2;
	sh2->r[n] = (UINT32)(INT32)(INT16) RW( sh2, sh2->ea );
}

/*  MOV.L   @(disp8,PC),Rn */
INLINE void MOVLI(sh2_state *sh2, UINT32 d, UINT32 n)
{
	UINT32 disp = d & 0xff;
	sh2->ea = ((sh2->pc + 2) & ~3) + disp * 4;
	sh2->r[n] = RL( sh2, sh2->ea );
}

/*  MOV.B   @(disp8,GBR),R0 */
INLINE void MOVBLG(sh2_state *sh2, UINT32 d)
{
	UINT32 disp = d & 0xff;
	sh2->ea = sh2->gbr + disp;
	sh2->r[0] = (UINT32)(INT32)(INT16)(INT8) RB( sh2, sh2->ea );
}

/*  MOV.W   @(disp8,GBR),R0 */
INLINE void MOVWLG(sh2_state *sh2, UINT32 d)
{
	UINT32 disp = d & 0xff;
	sh2->ea = sh2->gbr + disp * 2;
	sh2->r[0] = (INT32)(INT16) RW( sh2, sh2->ea );
}

/*  MOV.L   @(disp8,GBR),R0 */
INLINE void MOVLLG(sh2_state *sh2, UINT32 d)
{
	UINT32 disp = d & 0xff;
	sh2->ea = sh2->gbr + disp * 4;
	sh2->r[0] = RL( sh2, sh2->ea );
}

/*  MOV.B   R0,@(disp8,GBR) */
INLINE void MOVBSG(sh2_state *sh2, UINT32 d)
{
	UINT32 disp = d & 0xff;
	sh2->ea = sh2->gbr + disp;
	WB( sh2, sh2->ea, sh2->r[0] & 0x000000ff );
}

/*  MOV.W   R0,@(disp8,GBR) */
INLINE void MOVWSG(sh2_state *sh2, UINT32 d)
{
	UINT32 disp = d & 0xff;
	sh2->ea = sh2->gbr + disp * 2;
	WW( sh2, sh2->ea, sh2->r[0] & 0x0000ffff );
}

/*  MOV.L   R0,@(disp8,GBR) */
INLINE void MOVLSG(sh2_state *sh2, UINT32 d)
{
	UINT32 disp = d & 0xff;
	sh2->ea = sh2->gbr + disp * 4;
	WL( sh2, sh2->ea, sh2->r[0] );
}

/*  MOV.B   R0,@(disp4,Rn) */
INLINE void MOVBS4(sh2_state *sh2, UINT32 d, UINT32 n)
{
	UINT32 disp = d & 0x0f;
	sh2->ea = sh2->r[n] + disp;
	WB( sh2, sh2->ea, sh2->r[0] & 0x000000ff );
}

/*  MOV.W   R0,@(disp4,Rn) */
INLINE void MOVWS4(sh2_state *sh2, UINT32 d, UINT32 n)
{
	UINT32 disp = d & 0x0f;
	sh2->ea = sh2->r[n] + disp * 2;
	WW( sh2, sh2->ea, sh2->r[0] & 0x0000ffff );
}

/* MOV.L Rm,@(disp4,Rn) */
INLINE void MOVLS4(sh2_state *sh2, UINT32 m, UINT32 d, UINT32 n)
{
	UINT32 disp = d & 0x0f;
	sh2->ea = sh2->r[n] + disp * 4;
	WL( sh2, sh2->ea, sh2->r[m] );
}

/*  MOV.B   @(disp4,Rm),R0 */
INLINE void MOVBL4(sh2_state *sh2, UINT32 m, UINT32 d)
{
	UINT32 disp = d & 0x0f;
	sh2->ea = sh2->r[m] + disp;
	sh2->r[0] = (UINT32)(INT32)(INT16)(INT8) RB( sh2, sh2->ea );
}

/*  MOV.W   @(disp4,Rm),R0 */
INLINE void MOVWL4(sh2_state *sh2, UINT32 m, UINT32 d)
{
	UINT32 disp = d & 0x0f;
	sh2->ea = sh2->r[m] + disp * 2;
	sh2->r[0] = (UINT32)(INT32)(INT16) RW( sh2, sh2->ea );
}

/*  MOV.L   @(disp4,Rm),Rn */
INLINE void MOVLL4(sh2_state *sh2, UINT32 m, UINT32 d, UINT32 n)
{
	UINT32 disp = d & 0x0f;
	sh2->ea = sh2->r[m] + disp * 4;
	sh2->r[n] = RL( sh2, sh2->ea );
}

/*  MOVA    @(disp8,PC),R0 */
INLINE void MOVA(sh2_state *sh2, UINT32 d)
{
	UINT32 disp = d & 0xff;
	sh2->ea = ((sh2->pc + 2) & ~3) + disp * 4;
	sh2->r[0] = sh2->ea;
}

/*  MOVT    Rn */
INLINE void MOVT(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] = sh2->sr & T;
}

/*  MUL.L   Rm,Rn */
INLINE void MULL(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->macl = sh2->r[n] * sh2->r[m];
	sh2->icount--;
}

/*  MULS    Rm,Rn */
INLINE void MULS(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->macl = (INT16) sh2->r[n] * (INT16) sh2->r[m];
}

/*  MULU    Rm,Rn */
INLINE void MULU(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->macl = (UINT16) sh2->r[n] * (UINT16) sh2->r[m];
}

/*  NEG     Rm,Rn */
INLINE void NEG(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->r[n] = 0 - sh2->r[m];
}

/*  NEGC    Rm,Rn */
INLINE void NEGC(sh2_state *sh2, UINT32 m, UINT32 n)
{
	UINT32 temp;

	temp = sh2->r[m];
	sh2->r[n] = -temp - (sh2->sr & T);
	if (temp || (sh2->sr & T))
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
}

/*  NOP */
INLINE void NOP(void)
{
}

/*  NOT     Rm,Rn */
INLINE void NOT(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->r[n] = ~sh2->r[m];
}

/*  OR      Rm,Rn */
INLINE void OR(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->r[n] |= sh2->r[m];
}

/*  OR      #imm,R0 */
INLINE void ORI(sh2_state *sh2, UINT32 i)
{
	sh2->r[0] |= i;
}

/*  OR.B    #imm,@(R0,GBR) */
INLINE void ORM(sh2_state *sh2, UINT32 i)
{
	UINT32 temp;

	sh2->ea = sh2->gbr + sh2->r[0];
	temp = RB( sh2, sh2->ea );
	temp |= i;
	WB( sh2, sh2->ea, temp );
	sh2->icount -= 2;
}

/*  ROTCL   Rn */
INLINE void ROTCL(sh2_state *sh2, UINT32 n)
{
	UINT32 temp;

	temp = (sh2->r[n] >> 31) & T;
	sh2->r[n] = (sh2->r[n] << 1) | (sh2->sr & T);
	sh2->sr = (sh2->sr & ~T) | temp;
}

/*  ROTCR   Rn */
INLINE void ROTCR(sh2_state *sh2, UINT32 n)
{
	UINT32 temp;
	temp = (sh2->sr & T) << 31;
	if (sh2->r[n] & T)
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
	sh2->r[n] = (sh2->r[n] >> 1) | temp;
}

/*  ROTL    Rn */
INLINE void ROTL(sh2_state *sh2, UINT32 n)
{
	sh2->sr = (sh2->sr & ~T) | ((sh2->r[n] >> 31) & T);
	sh2->r[n] = (sh2->r[n] << 1) | (sh2->r[n] >> 31);
}

/*  ROTR    Rn */
INLINE void ROTR(sh2_state *sh2, UINT32 n)
{
	sh2->sr = (sh2->sr & ~T) | (sh2->r[n] & T);
	sh2->r[n] = (sh2->r[n] >> 1) | (sh2->r[n] << 31);
}

/*  RTE */
INLINE void RTE(sh2_state *sh2)
{
	sh2->ea = sh2->r[15];
	sh2->delay = sh2->pc;
	sh2->pc = RL( sh2, sh2->ea );
	sh2->r[15] += 4;
	sh2->ea = sh2->r[15];
	sh2->sr = RL( sh2, sh2->ea ) & FLAGS;
	sh2->r[15] += 4;
	sh2->icount -= 3;
	sh2->test_irq = 1;
}

/*  RTS */
INLINE void RTS(sh2_state *sh2)
{
	sh2->delay = sh2->pc;
	sh2->pc = sh2->ea = sh2->pr;
	sh2->icount--;
}

/*  SETT */
INLINE void SETT(sh2_state *sh2)
{
	sh2->sr |= T;
}

/*  SHAL    Rn      (same as SHLL) */
INLINE void SHAL(sh2_state *sh2, UINT32 n)
{
	sh2->sr = (sh2->sr & ~T) | ((sh2->r[n] >> 31) & T);
	sh2->r[n] <<= 1;
}

/*  SHAR    Rn */
INLINE void SHAR(sh2_state *sh2, UINT32 n)
{
	sh2->sr = (sh2->sr & ~T) | (sh2->r[n] & T);
	sh2->r[n] = (UINT32)((INT32)sh2->r[n] >> 1);
}

/*  SHLL    Rn      (same as SHAL) */
INLINE void SHLL(sh2_state *sh2, UINT32 n)
{
	sh2->sr = (sh2->sr & ~T) | ((sh2->r[n] >> 31) & T);
	sh2->r[n] <<= 1;
}

/*  SHLL2   Rn */
INLINE void SHLL2(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] <<= 2;
}

/*  SHLL8   Rn */
INLINE void SHLL8(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] <<= 8;
}

/*  SHLL16  Rn */
INLINE void SHLL16(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] <<= 16;
}

/*  SHLR    Rn */
INLINE void SHLR(sh2_state *sh2, UINT32 n)
{
	sh2->sr = (sh2->sr & ~T) | (sh2->r[n] & T);
	sh2->r[n] >>= 1;
}

/*  SHLR2   Rn */
INLINE void SHLR2(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] >>= 2;
}

/*  SHLR8   Rn */
INLINE void SHLR8(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] >>= 8;
}

/*  SHLR16  Rn */
INLINE void SHLR16(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] >>= 16;
}

/*  SLEEP */
INLINE void SLEEP(sh2_state *sh2)
{
	//if(sh2->sleep_mode != 2)
		sh2->pc -= 2;
	sh2->icount -= 2;
	/* Wait_for_exception; */
	/*if(sh2->sleep_mode == 0)
		sh2->sleep_mode = 1;
	else if(sh2->sleep_mode == 2)
		sh2->sleep_mode = 0;*/
}

/*  STC     SR,Rn */
INLINE void STCSR(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] = sh2->sr;
}

/*  STC     GBR,Rn */
INLINE void STCGBR(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] = sh2->gbr;
}

/*  STC     VBR,Rn */
INLINE void STCVBR(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] = sh2->vbr;
}

/*  STC.L   SR,@-Rn */
INLINE void STCMSR(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] -= 4;
	sh2->ea = sh2->r[n];
	WL( sh2, sh2->ea, sh2->sr );
	sh2->icount--;
}

/*  STC.L   GBR,@-Rn */
INLINE void STCMGBR(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] -= 4;
	sh2->ea = sh2->r[n];
	WL( sh2, sh2->ea, sh2->gbr );
	sh2->icount--;
}

/*  STC.L   VBR,@-Rn */
INLINE void STCMVBR(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] -= 4;
	sh2->ea = sh2->r[n];
	WL( sh2, sh2->ea, sh2->vbr );
	sh2->icount--;
}

/*  STS     MACH,Rn */
INLINE void STSMACH(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] = sh2->mach;
}

/*  STS     MACL,Rn */
INLINE void STSMACL(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] = sh2->macl;
}

/*  STS     PR,Rn */
INLINE void STSPR(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] = sh2->pr;
}

/*  STS.L   MACH,@-Rn */
INLINE void STSMMACH(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] -= 4;
	sh2->ea = sh2->r[n];
	WL( sh2, sh2->ea, sh2->mach );
}

/*  STS.L   MACL,@-Rn */
INLINE void STSMMACL(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] -= 4;
	sh2->ea = sh2->r[n];
	WL( sh2, sh2->ea, sh2->macl );
}

/*  STS.L   PR,@-Rn */
INLINE void STSMPR(sh2_state *sh2, UINT32 n)
{
	sh2->r[n] -= 4;
	sh2->ea = sh2->r[n];
	WL( sh2, sh2->ea, sh2->pr );
}

/*  SUB     Rm,Rn */
INLINE void SUB(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->r[n] -= sh2->r[m];
}

/*  SUBC    Rm,Rn */
INLINE void SUBC(sh2_state *sh2, UINT32 m, UINT32 n)
{
	UINT32 tmp0, tmp1;

	tmp1 = sh2->r[n] - sh2->r[m];
	tmp0 = sh2->r[n];
	sh2->r[n] = tmp1 - (sh2->sr & T);
	if (tmp0 < tmp1)
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
	if (tmp1 < sh2->r[n])
		sh2->sr |= T;
}

/*  SUBV    Rm,Rn */
INLINE void SUBV(sh2_state *sh2, UINT32 m, UINT32 n)
{
	INT32 dest, src, ans;

	if ((INT32) sh2->r[n] >= 0)
		dest = 0;
	else
		dest = 1;
	if ((INT32) sh2->r[m] >= 0)
		src = 0;
	else
		src = 1;
	src += dest;
	sh2->r[n] -= sh2->r[m];
	if ((INT32) sh2->r[n] >= 0)
		ans = 0;
	else
		ans = 1;
	ans += dest;
	if (src == 1)
	{
		if (ans == 1)
			sh2->sr |= T;
		else
			sh2->sr &= ~T;
	}
	else
		sh2->sr &= ~T;
}

/*  SWAP.B  Rm,Rn */
INLINE void SWAPB(sh2_state *sh2, UINT32 m, UINT32 n)
{
	UINT32 temp0, temp1;

	temp0 = sh2->r[m] & 0xffff0000;
	temp1 = (sh2->r[m] & 0x000000ff) << 8;
	sh2->r[n] = (sh2->r[m] >> 8) & 0x000000ff;
	sh2->r[n] = sh2->r[n] | temp1 | temp0;
}

/*  SWAP.W  Rm,Rn */
INLINE void SWAPW(sh2_state *sh2, UINT32 m, UINT32 n)
{
	UINT32 temp;

	temp = (sh2->r[m] >> 16) & 0x0000ffff;
	sh2->r[n] = (sh2->r[m] << 16) | temp;
}

/*  TAS.B   @Rn */
INLINE void TAS(sh2_state *sh2, UINT32 n)
{
	UINT32 temp;
	sh2->ea = sh2->r[n];
	/* Bus Lock enable */
	temp = RB( sh2, sh2->ea );
	if (temp == 0)
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
	temp |= 0x80;
	/* Bus Lock disable */
	WB( sh2, sh2->ea, temp );
	sh2->icount -= 3;
}

/*  TRAPA   #imm */
INLINE void TRAPA(sh2_state *sh2, UINT32 i)
{
	UINT32 imm = i & 0xff;

	sh2->ea = sh2->vbr + imm * 4;

	sh2->r[15] -= 4;
	WL( sh2, sh2->r[15], sh2->sr );
	sh2->r[15] -= 4;
	WL( sh2, sh2->r[15], sh2->pc );

	sh2->pc = RL( sh2, sh2->ea );

	sh2->icount -= 7;
}

/*  TST     Rm,Rn */
INLINE void TST(sh2_state *sh2, UINT32 m, UINT32 n)
{
	if ((sh2->r[n] & sh2->r[m]) == 0)
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
}

/*  TST     #imm,R0 */
INLINE void TSTI(sh2_state *sh2, UINT32 i)
{
	UINT32 imm = i & 0xff;

	if ((imm & sh2->r[0]) == 0)
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
}

/*  TST.B   #imm,@(R0,GBR) */
INLINE void TSTM(sh2_state *sh2, UINT32 i)
{
	UINT32 imm = i & 0xff;

	sh2->ea = sh2->gbr + sh2->r[0];
	if ((imm & RB( sh2, sh2->ea )) == 0)
		sh2->sr |= T;
	else
		sh2->sr &= ~T;
	sh2->icount -= 2;
}

/*  XOR     Rm,Rn */
INLINE void XOR(sh2_state *sh2, UINT32 m, UINT32 n)
{
	sh2->r[n] ^= sh2->r[m];
}

/*  XOR     #imm,R0 */
INLINE void XORI(sh2_state *sh2, UINT32 i)
{
	UINT32 imm = i & 0xff;
	sh2->r[0] ^= imm;
}

/*  XOR.B   #imm,@(R0,GBR) */
INLINE void XORM(sh2_state *sh2, UINT32 i)
{
	UINT32 imm = i & 0xff;
	UINT32 temp;

	sh2->ea = sh2->gbr + sh2->r[0];
	temp = RB( sh2, sh2->ea );
	temp ^= imm;
	WB( sh2, sh2->ea, temp );
	sh2->icount -= 2;
}

/*  XTRCT   Rm,Rn */
INLINE void XTRCT(sh2_state *sh2, UINT32 m, UINT32 n)
{
	UINT32 temp;

	temp = (sh2->r[m] << 16) & 0xffff0000;
	sh2->r[n] = (sh2->r[n] >> 16) & 0x0000ffff;
	sh2->r[n] |= temp;
}

/*****************************************************************************
 *  OPCODE DISPATCHERS
 *****************************************************************************/

INLINE void op0000(sh2_state *sh2, UINT16 opcode)
{
	switch (opcode & 0x3F)
	{
	case 0x00: ILLEGAL(sh2);	rlog(0);			break;
	case 0x01: ILLEGAL(sh2);	rlog(0);			break;
	case 0x02: STCSR(sh2, Rn);	rlog(LRN); 			break;
	case 0x03: BSRF(sh2, Rn);	rlog(LRN); 			break;
	case 0x04: MOVBS0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x05: MOVWS0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x06: MOVLS0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x07: MULL(sh2, Rm, Rn);	rlog(LRNM); rlog1(SHR_MACL);	break;
	case 0x08: CLRT(sh2);		rlog(0);			break;
	case 0x09: NOP();		rlog(0);			break;
	case 0x0a: STSMACH(sh2, Rn); 	rlog(LRN);  rlog1(SHR_MACH); 	break;
	case 0x0b: RTS(sh2);		rlog(0);    rlog1(SHR_PR);	break;
	case 0x0c: MOVBL0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x0d: MOVWL0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x0e: MOVLL0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x0f: MAC_L(sh2, Rm, Rn);	rlog(LRNM); rlog2(SHR_MACL,SHR_MACH); break;

	case 0x10: ILLEGAL(sh2);	rlog(0);			break;
	case 0x11: ILLEGAL(sh2);	rlog(0);			break;
	case 0x12: STCGBR(sh2, Rn);	rlog(LRN);  rlog1(SHR_GBR);	break;
	case 0x13: ILLEGAL(sh2);	rlog(0);			break;
	case 0x14: MOVBS0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x15: MOVWS0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x16: MOVLS0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x17: MULL(sh2, Rm, Rn);	rlog(LRNM); rlog1(SHR_MACL);	break;
	case 0x18: SETT(sh2);		rlog(0);			break;
	case 0x19: DIV0U(sh2); 		rlog(0);			break;
	case 0x1a: STSMACL(sh2, Rn); 	rlog(LRN);  rlog1(SHR_MACL);	break;
	case 0x1b: SLEEP(sh2); 		rlog(0);			break;
	case 0x1c: MOVBL0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x1d: MOVWL0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x1e: MOVLL0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x1f: MAC_L(sh2, Rm, Rn);	rlog(LRNM); rlog2(SHR_MACL,SHR_MACH); break;

	case 0x20: ILLEGAL(sh2);	rlog(0);			break;
	case 0x21: ILLEGAL(sh2);	rlog(0);			break;
	case 0x22: STCVBR(sh2, Rn);	rlog(LRN);  rlog1(SHR_VBR);	break;
	case 0x23: BRAF(sh2, Rn);	rlog(LRN);			break;
	case 0x24: MOVBS0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x25: MOVWS0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x26: MOVLS0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x27: MULL(sh2, Rm, Rn);	rlog(LRNM); rlog1(SHR_MACL);	break;
	case 0x28: CLRMAC(sh2);		rlog(0);    rlog2(SHR_MACL,SHR_MACH); break;
	case 0x29: MOVT(sh2, Rn);	rlog(LRN);			break;
	case 0x2a: STSPR(sh2, Rn);	rlog(LRN);  rlog1(SHR_PR);	break;
	case 0x2b: RTE(sh2);		rlog(0);			break;
	case 0x2c: MOVBL0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x2d: MOVWL0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x2e: MOVLL0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x2f: MAC_L(sh2, Rm, Rn);	rlog(LRNM); rlog2(SHR_MACL,SHR_MACH); break;

	case 0x30: ILLEGAL(sh2);	rlog(0);			break;
	case 0x31: ILLEGAL(sh2);	rlog(0);			break;
	case 0x32: ILLEGAL(sh2);	rlog(0);			break;
	case 0x33: ILLEGAL(sh2);	rlog(0);			break;
	case 0x34: MOVBS0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x35: MOVWS0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x36: MOVLS0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x37: MULL(sh2, Rm, Rn);	rlog(LRNM); rlog1(SHR_MACL);	break;
	case 0x38: ILLEGAL(sh2);	rlog(0);			break;
	case 0x39: ILLEGAL(sh2);	rlog(0);			break;
	case 0x3c: MOVBL0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x3d: MOVWL0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x3e: MOVLL0(sh2, Rm, Rn);	rlog(LRNM); rlog1(0);		break;
	case 0x3f: MAC_L(sh2, Rm, Rn);	rlog(LRNM); rlog2(SHR_MACL,SHR_MACH); break;
	case 0x3a: ILLEGAL(sh2);	rlog(0);			break;
	case 0x3b: ILLEGAL(sh2);	rlog(0);			break;
	}
}

INLINE void op0001(sh2_state *sh2, UINT16 opcode)
{
	MOVLS4(sh2, Rm, opcode & 0x0f, Rn);
	rlog(LRNM);
}

INLINE void op0010(sh2_state *sh2, UINT16 opcode)
{
	switch (opcode & 15)
	{
	case  0: MOVBS(sh2, Rm, Rn); 	rlog(LRNM);			break;
	case  1: MOVWS(sh2, Rm, Rn); 	rlog(LRNM);			break;
	case  2: MOVLS(sh2, Rm, Rn); 	rlog(LRNM);			break;
	case  3: ILLEGAL(sh2);		rlog(0);			break;
	case  4: MOVBM(sh2, Rm, Rn); 	rlog(LRNM);			break;
	case  5: MOVWM(sh2, Rm, Rn); 	rlog(LRNM);			break;
	case  6: MOVLM(sh2, Rm, Rn); 	rlog(LRNM);			break;
	case  7: DIV0S(sh2, Rm, Rn); 	rlog(LRNM);			break;
	case  8: TST(sh2, Rm, Rn);	rlog(LRNM);			break;
	case  9: AND(sh2, Rm, Rn);	rlog(LRNM);			break;
	case 10: XOR(sh2, Rm, Rn);	rlog(LRNM);			break;
	case 11: OR(sh2, Rm, Rn);	rlog(LRNM);			break;
	case 12: CMPSTR(sh2, Rm, Rn);	rlog(LRNM);			break;
	case 13: XTRCT(sh2, Rm, Rn); 	rlog(LRNM);			break;
	case 14: MULU(sh2, Rm, Rn);	rlog(LRNM); rlog1(SHR_MACL);	break;
	case 15: MULS(sh2, Rm, Rn);	rlog(LRNM); rlog1(SHR_MACL);	break;
	}
}

INLINE void op0011(sh2_state *sh2, UINT16 opcode)
{
	switch (opcode & 15)
	{
	case  0: CMPEQ(sh2, Rm, Rn); 	rlog(LRNM);			break;
	case  1: ILLEGAL(sh2);		rlog(0);			break;
	case  2: CMPHS(sh2, Rm, Rn); 	rlog(LRNM);			break;
	case  3: CMPGE(sh2, Rm, Rn); 	rlog(LRNM);			break;
	case  4: DIV1(sh2, Rm, Rn);	rlog(LRNM);			break;
	case  5: DMULU(sh2, Rm, Rn); 	rlog(LRNM); rlog2(SHR_MACL,SHR_MACH); break;
	case  6: CMPHI(sh2, Rm, Rn); 	rlog(LRNM);			break;
	case  7: CMPGT(sh2, Rm, Rn); 	rlog(LRNM);			break;
	case  8: SUB(sh2, Rm, Rn);	rlog(LRNM);			break;
	case  9: ILLEGAL(sh2);		rlog(0);			break;
	case 10: SUBC(sh2, Rm, Rn);	rlog(LRNM);			break;
	case 11: SUBV(sh2, Rm, Rn);	rlog(LRNM);			break;
	case 12: ADD(sh2, Rm, Rn);	rlog(LRNM);			break;
	case 13: DMULS(sh2, Rm, Rn); 	rlog(LRNM); rlog2(SHR_MACL,SHR_MACH); break;
	case 14: ADDC(sh2, Rm, Rn);	rlog(LRNM);			break;
	case 15: ADDV(sh2, Rm, Rn);	rlog(LRNM);			break;
	}
}

INLINE void op0100(sh2_state *sh2, UINT16 opcode)
{
	switch (opcode & 0x3F)
	{
	case 0x00: SHLL(sh2, Rn);	rlog(LRN);			break;
	case 0x01: SHLR(sh2, Rn);	rlog(LRN);			break;
	case 0x02: STSMMACH(sh2, Rn);	rlog(LRN); rlog1(SHR_MACH);	break;
	case 0x03: STCMSR(sh2, Rn);	rlog(LRN);			break;
	case 0x04: ROTL(sh2, Rn);	rlog(LRN);			break;
	case 0x05: ROTR(sh2, Rn);	rlog(LRN);			break;
	case 0x06: LDSMMACH(sh2, Rn);	rlog(LRN); rlog1(SHR_MACH);	break;
	case 0x07: LDCMSR(sh2, Rn);	rlog(LRN);			break;
	case 0x08: SHLL2(sh2, Rn);	rlog(LRN);			break;
	case 0x09: SHLR2(sh2, Rn);	rlog(LRN);			break;
	case 0x0a: LDSMACH(sh2, Rn); 	rlog(LRN); rlog1(SHR_MACH);	break;
	case 0x0b: JSR(sh2, Rn); 	rlog(LRN); rlog1(SHR_PR);	break;
	case 0x0c: ILLEGAL(sh2);	rlog(0);			break;
	case 0x0d: ILLEGAL(sh2);	rlog(0);			break;
	case 0x0e: LDCSR(sh2, Rn);	rlog(LRN);			break;
	case 0x0f: MAC_W(sh2, Rm, Rn);	rlog(LRNM); rlog2(SHR_MACL,SHR_MACH); break;

	case 0x10: DT(sh2, Rn);		rlog(LRN);			break;
	case 0x11: CMPPZ(sh2, Rn);	rlog(LRN);			break;
	case 0x12: STSMMACL(sh2, Rn);	rlog(LRN); rlog1(SHR_MACL);	break;
	case 0x13: STCMGBR(sh2, Rn); 	rlog(LRN); rlog1(SHR_GBR);	break;
	case 0x14: ILLEGAL(sh2);	rlog(0);			break;
	case 0x15: CMPPL(sh2, Rn);	rlog(LRN);			break;
	case 0x16: LDSMMACL(sh2, Rn);	rlog(LRN); rlog1(SHR_MACL);	break;
	case 0x17: LDCMGBR(sh2, Rn); 	rlog(LRN); rlog1(SHR_GBR);	break;
	case 0x18: SHLL8(sh2, Rn);	rlog(LRN);			break;
	case 0x19: SHLR8(sh2, Rn);	rlog(LRN);			break;
	case 0x1a: LDSMACL(sh2, Rn); 	rlog(LRN); rlog1(SHR_MACL);	break;
	case 0x1b: TAS(sh2, Rn); 	rlog(LRN);			break;
	case 0x1c: ILLEGAL(sh2);	rlog(0);			break;
	case 0x1d: ILLEGAL(sh2);	rlog(0);			break;
	case 0x1e: LDCGBR(sh2, Rn);	rlog(LRN); rlog1(SHR_GBR);	break;
	case 0x1f: MAC_W(sh2, Rm, Rn);	rlog(LRNM); rlog2(SHR_MACL,SHR_MACH); break;

	case 0x20: SHAL(sh2, Rn);	rlog(LRN);			break;
	case 0x21: SHAR(sh2, Rn);	rlog(LRN);			break;
	case 0x22: STSMPR(sh2, Rn);	rlog(LRN); rlog1(SHR_PR);	break;
	case 0x23: STCMVBR(sh2, Rn); 	rlog(LRN); rlog1(SHR_VBR);	break;
	case 0x24: ROTCL(sh2, Rn);	rlog(LRN);			break;
	case 0x25: ROTCR(sh2, Rn);	rlog(LRN);			break;
	case 0x26: LDSMPR(sh2, Rn);	rlog(LRN); rlog1(SHR_PR);	break;
	case 0x27: LDCMVBR(sh2, Rn); 	rlog(LRN); rlog1(SHR_VBR);	break;
	case 0x28: SHLL16(sh2, Rn);	rlog(LRN);			break;
	case 0x29: SHLR16(sh2, Rn);	rlog(LRN);			break;
	case 0x2a: LDSPR(sh2, Rn);	rlog(LRN); rlog1(SHR_PR);	break;
	case 0x2b: JMP(sh2, Rn); 	rlog(LRN);			break;
	case 0x2c: ILLEGAL(sh2);	rlog(0);			break;
	case 0x2d: ILLEGAL(sh2);	rlog(0);			break;
	case 0x2e: LDCVBR(sh2, Rn);	rlog(LRN); rlog1(SHR_VBR);	break;
	case 0x2f: MAC_W(sh2, Rm, Rn);	rlog(LRNM); rlog2(SHR_MACL,SHR_MACH); break;

	case 0x30:
	case 0x31:
	case 0x32:
	case 0x33:
	case 0x34:
	case 0x35:
	case 0x36:
	case 0x37:
	case 0x38:
	case 0x39:
	case 0x3a:
	case 0x3b:
	case 0x3c:
	case 0x3d:
	case 0x3e: ILLEGAL(sh2);	rlog(0);			break;
	case 0x3f: MAC_W(sh2, Rm, Rn);	rlog(LRNM); rlog2(SHR_MACL,SHR_MACH); break;
	}
}

INLINE void op0101(sh2_state *sh2, UINT16 opcode)
{
	MOVLL4(sh2, Rm, opcode & 0x0f, Rn);
	rlog(LRNM);
}

INLINE void op0110(sh2_state *sh2, UINT16 opcode)
{
	switch (opcode & 15)
	{
	case  0: MOVBL(sh2, Rm, Rn); 				break;
	case  1: MOVWL(sh2, Rm, Rn); 				break;
	case  2: MOVLL(sh2, Rm, Rn); 				break;
	case  3: MOV(sh2, Rm, Rn);				break;
	case  4: MOVBP(sh2, Rm, Rn); 				break;
	case  5: MOVWP(sh2, Rm, Rn); 				break;
	case  6: MOVLP(sh2, Rm, Rn); 				break;
	case  7: NOT(sh2, Rm, Rn);				break;
	case  8: SWAPB(sh2, Rm, Rn); 				break;
	case  9: SWAPW(sh2, Rm, Rn); 				break;
	case 10: NEGC(sh2, Rm, Rn);				break;
	case 11: NEG(sh2, Rm, Rn);				break;
	case 12: EXTUB(sh2, Rm, Rn); 				break;
	case 13: EXTUW(sh2, Rm, Rn); 				break;
	case 14: EXTSB(sh2, Rm, Rn); 				break;
	case 15: EXTSW(sh2, Rm, Rn); 				break;
	}
	rlog(LRNM);
}

INLINE void op0111(sh2_state *sh2, UINT16 opcode)
{
	ADDI(sh2, opcode & 0xff, Rn);
	rlog(LRN);
}

INLINE void op1000(sh2_state *sh2, UINT16 opcode)
{
	switch ( opcode  & (15<<8) )
	{
	case  0<< 8: MOVBS4(sh2, opcode & 0x0f, Rm);	rlog(LRM); rlog1(0);	break;
	case  1<< 8: MOVWS4(sh2, opcode & 0x0f, Rm);	rlog(LRM); rlog1(0);	break;
	case  2<< 8: ILLEGAL(sh2); 			rlog(0);		break;
	case  3<< 8: ILLEGAL(sh2); 			rlog(0);		break;
	case  4<< 8: MOVBL4(sh2, Rm, opcode & 0x0f);	rlog(LRM); rlog1(0);	break;
	case  5<< 8: MOVWL4(sh2, Rm, opcode & 0x0f);	rlog(LRM); rlog1(0);	break;
	case  6<< 8: ILLEGAL(sh2); 			rlog(0);		break;
	case  7<< 8: ILLEGAL(sh2); 			rlog(0);		break;
	case  8<< 8: CMPIM(sh2, opcode & 0xff);		rlog(0);   rlog1(0);	break;
	case  9<< 8: BT(sh2, opcode & 0xff); 		rlog(0);	break;
	case 10<< 8: ILLEGAL(sh2); 			rlog(0);	break;
	case 11<< 8: BF(sh2, opcode & 0xff); 		rlog(0);	break;
	case 12<< 8: ILLEGAL(sh2); 			rlog(0);	break;
	case 13<< 8: BTS(sh2, opcode & 0xff);		rlog(0);	break;
	case 14<< 8: ILLEGAL(sh2); 			rlog(0);	break;
	case 15<< 8: BFS(sh2, opcode & 0xff);		rlog(0);	break;
	}
}


INLINE void op1001(sh2_state *sh2, UINT16 opcode)
{
	MOVWI(sh2, opcode & 0xff, Rn);
	rlog(LRN);
}

INLINE void op1010(sh2_state *sh2, UINT16 opcode)
{
	BRA(sh2, opcode & 0xfff);
	rlog(0);
}

INLINE void op1011(sh2_state *sh2, UINT16 opcode)
{
	BSR(sh2, opcode & 0xfff);
	rlog(0);
	rlog1(SHR_PR);
}

INLINE void op1100(sh2_state *sh2, UINT16 opcode)
{
	switch (opcode & (15<<8))
	{
	case  0<<8: MOVBSG(sh2, opcode & 0xff); rlog2(0, SHR_GBR);	break;
	case  1<<8: MOVWSG(sh2, opcode & 0xff); rlog2(0, SHR_GBR);	break;
	case  2<<8: MOVLSG(sh2, opcode & 0xff); rlog2(0, SHR_GBR);	break;
	case  3<<8: TRAPA(sh2, opcode & 0xff);	rlog1(SHR_VBR);		break;
	case  4<<8: MOVBLG(sh2, opcode & 0xff); rlog2(0, SHR_GBR);	break;
	case  5<<8: MOVWLG(sh2, opcode & 0xff); rlog2(0, SHR_GBR);	break;
	case  6<<8: MOVLLG(sh2, opcode & 0xff); rlog2(0, SHR_GBR);	break;
	case  7<<8: MOVA(sh2, opcode & 0xff);	rlog1(0);		break;
	case  8<<8: TSTI(sh2, opcode & 0xff);	rlog1(0);		break;
	case  9<<8: ANDI(sh2, opcode & 0xff);	rlog1(0);		break;
	case 10<<8: XORI(sh2, opcode & 0xff);	rlog1(0);		break;
	case 11<<8: ORI(sh2, opcode & 0xff);	rlog1(0);		break;
	case 12<<8: TSTM(sh2, opcode & 0xff);	rlog2(0, SHR_GBR);	break;
	case 13<<8: ANDM(sh2, opcode & 0xff);	rlog2(0, SHR_GBR);	break;
	case 14<<8: XORM(sh2, opcode & 0xff);	rlog2(0, SHR_GBR);	break;
	case 15<<8: ORM(sh2, opcode & 0xff);	rlog2(0, SHR_GBR);	break;
	}
	rlog(0);
}

INLINE void op1101(sh2_state *sh2, UINT16 opcode)
{
	MOVLI(sh2, opcode & 0xff, Rn);
	rlog(LRN);
}

INLINE void op1110(sh2_state *sh2, UINT16 opcode)
{
	MOVI(sh2, opcode & 0xff, Rn);
	rlog(LRN);
}

INLINE void op1111(sh2_state *sh2, UINT16 opcode)
{
	ILLEGAL(sh2);
	rlog(0);
}

#endif
