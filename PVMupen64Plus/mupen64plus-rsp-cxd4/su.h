/******************************************************************************\
* Project:  Basic MIPS R4000 Instruction Set for Scalar Unit Operations        *
* Authors:  Iconoclast                                                         *
* Release:  2016.11.05                                                         *
* License:  CC0 Public Domain Dedication                                       *
*                                                                              *
* To the extent possible under law, the author(s) have dedicated all copyright *
* and related and neighboring rights to this software to the public domain     *
* worldwide. This software is distributed without any warranty.                *
*                                                                              *
* You should have received a copy of the CC0 Public Domain Dedication along    *
* with this software.                                                          *
* If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.             *
\******************************************************************************/

#ifndef _SU_H_
#define _SU_H_

#include <limits.h>
#include <stdio.h>

#include "my_types.h"
#include "rsp.h"

#define EXTERN_COMMAND_LIST_GBI
#define EXTERN_COMMAND_LIST_ABI
#define SEMAPHORE_LOCK_CORRECTIONS
#define WAIT_FOR_CPU_HOST

#if (0)
#define SP_EXECUTE_LOG
#define VU_EMULATE_SCALAR_ACCUMULATOR_READ
#endif

/*
 * Currently, the plugin system this module is written for doesn't notify us
 * of how much RDRAM is installed to the system, so we have to presume 8 MiB.
 */
#define MAX_DRAM_ADDR           0x007FFFFFul
#define MAX_DRAM_DMA_ADDR       (MAX_DRAM_ADDR & ~7)

/*
 * Interact with memory using server-side byte order (MIPS big-endian) or
 * client-side (VM host's) native byte order on a 32-bit boundary.
 *
 * Unfortunately, most op-codes are optimized to require this to be TRUE.
 */
#if (ENDIAN_M == 0)
#define USE_CLIENT_ENDIAN       0
#else
#define USE_CLIENT_ENDIAN       1
#endif

/*
 * Always keep this enabled for faster interpreter CPU.
 *
 * If you disable this, the branch delay slot algorithm will match the
 * documentation found in the MIPS manuals (which is not entirely accurate).
 *
 * Enabled:
 *     while (CPU_running) {
 *         PC = static_delay_slot_adjustments();
 *         switch (opcode) { ... continue; }
 * Disabled:
 *     while (CPU_running) {
 *         switch (opcode) { ... break; }
 *         PC = documented_branch_delay_slot();
 *         continue;
 */
#if 1
#define EMULATE_STATIC_PC
#endif

#if (0 != 0)
#define PROFILE_MODE    static NOINLINE
#else
#define PROFILE_MODE    static INLINE
#endif

typedef enum {
    zero = 0,
    at =  1,
#ifdef TRUE_MIPS_AND_NOT_JUST_THE_RSP_SUBSET
    v0 =  2,
    v1 =  3,

    a0 =  4,
    a1 =  5,
    a2 =  6,
    a3 =  7,

    t0 =  8,
    t1 =  9,
    t2 = 10,
    t3 = 11,
    t4 = 12,
    t5 = 13,
    t6 = 14,
    t7 = 15,
    t8 = 24,
    t9 = 25,

    s0 = 16,
    s1 = 17,
    s2 = 18,
    s3 = 19,
    s4 = 20,
    s5 = 21,
    s6 = 22,
    s7 = 23,

    k0 = 26,
    k1 = 27,

    gp = 28,
#endif
    sp = 29,
    fp = 30, /* new, official MIPS name for it:  "frame pointer" */
    ra = 31,
    S8 = fp
} GPR_specifier;

extern RSP_INFO RSP_INFO_NAME;
extern pu8 DRAM;
extern pu8 DMEM;
extern pu8 IMEM;

extern u8 conf[32];

/*
 * general-purpose scalar registers
 *
 * based on the MIPS instruction set architecture but without most of the
 * original register names (for example, no kernel-reserved registers)
 */
extern u32 SR[32];

#define FIT_IMEM(PC)    ((PC) & 0xFFFu & 0xFFCu)

#ifdef EMULATE_STATIC_PC
#define JUMP        goto set_branch_delay
#else
#define JUMP        break
#endif

#ifdef EMULATE_STATIC_PC
#define BASE_OFF    0x000
#else
#define BASE_OFF    0x004
#endif

#ifndef EMULATE_STATIC_PC
int stage;
#endif

extern int temp_PC;
#ifdef WAIT_FOR_CPU_HOST
extern short MFC0_count[32];
/* Keep one C0 MF status read count for each scalar register. */
#endif

/*
 * The number of times to tolerate executing `MFC0    $at, $c4`.
 * Replace $at with any register--the timeout limit is per each.
 *
 * Set to a higher value to avoid prematurely quitting the interpreter.
 * Set to a lower value for speed...you could get away with 10 sometimes.
 */
extern int MF_SP_STATUS_TIMEOUT;

#define SLOT_OFF    ((BASE_OFF) + 0x000)
#define LINK_OFF    ((BASE_OFF) + 0x004)
extern void set_PC(unsigned int address);

/*
 * If the client CPU's shift amount is exactly 5 bits for a 32-bit source,
 * then omit emulating (sa & 31) in the SLL/SRL/SRA interpreter steps.
 * (Additionally, omit doing (GPR[rs] & 31) in SLLV/SRLV/SRAV.)
 *
 * As C pre-processor logic seems incapable of interpreting type storage,
 * stuff like #if (1U << 31 == 1U << ~0U) will generally just fail.
 *
 * Some of these also will only work assuming 2's complement (e.g., Intel).
 */
#if defined(ARCH_MIN_SSE2)
#define MASK_SA(sa)             (sa)
#define IW_RD(inst)             ((u16)(inst) >> 11)
#define SIGNED_IMM16(imm)       (s16)(imm)
#else
#define MASK_SA(sa)             ((sa) & 31)
#define IW_RD(inst)             (u8)(((inst) >> 11) % (1 << 5))
#define SIGNED_IMM16(imm)       (s16)(((imm) & 0x8000u) ? -(~(imm) + 1) : (imm))
#endif

/*
 * If primary op-code is SPECIAL (000000), we could skip ANDing the rs shift.
 * Shifts losing precision are undefined, so don't assume that (1 >> 1 == 0).
 */
#if (0xFFFFFFFFul >> 31 != 0x000000001ul) || defined(_DEBUG)
#define SPECIAL_DECODE_RS(inst)     (((inst) & 0x03E00000UL) >> 21)
#else
#define SPECIAL_DECODE_RS(inst)     ((inst) >> 21)
#endif

/*
 * Try to stick to (unsigned char) to conform to strict aliasing rules.
 *
 * Do not say `u8`.  My custom type definitions are minimum-size types.
 * Do not say `uint8_t`.  Exact-width types are not portable/universal.
 */
#if (CHAR_BIT != 8)
#error Non-POSIX-compliant (char) storage width.
#endif

/*
 * RSP general-purpose registers (GPRs) are always 32-bit scalars (SRs).
 * SR_B(gpr, 0) is SR[gpr]31..24, and SR_B(gpr, 3) is SR[gpr]7..0.
 */
#define SR_B(scalar, i)         *((unsigned char *)&(SR[scalar]) + BES(i))

/*
 * Universal byte-access macro for 8-element vectors of 16-bit halfwords.
 * Use this macro if you are not sure whether the element is odd or even.
 *
 * Maybe a typedef union{} can be better, but it's less readable for RSP
 * vector registers.  Only 16-bit element computations exist, so the correct
 * allocation of the register file is int16_t v[32][8], not a_union v[32].
 *
 * Either method--dynamic union reads or special aliasing--is undefined
 * behavior and will not truly be portable code anyway, so it hardly matters.
 */
#define VR_B(vt, element)       *((unsigned char *)&(VR[vt][0]) + MES(element))

/*
 * Optimized byte-access macros for the vector registers.
 * Use these ONLY if you know the element is even (VR_A) or odd (VR_U).
 *
 * They are faster because LEA PTR [offset +/- 1] means fewer CPU
 * instructions generated than (offset ^ 1) does, in most cases.
 */
#define VR_A(vt, e)             *((unsigned char *)&(VR[vt][0]) + e + MES(0))
#define VR_U(vt, e)             *((unsigned char *)&(VR[vt][0]) + e - MES(0))

/*
 * Use this ONLY if you know the element is even, not odd.
 *
 * This is only provided for purposes of consistency with VR_B() and friends.
 * Saying `VR[vt][1] = x;` instead of `VR_S(vt, 2) = x` works as well.
 */
#define VR_S(vt, element)       *(pi16)((unsigned char *)&(VR[vt][0]) + element)

/*** Scalar, Coprocessor Operations (system control) ***/
#define SP_STATUS_HALT          (0x00000001ul <<  0)
#define SP_STATUS_BROKE         (0x00000001ul <<  1)
#define SP_STATUS_DMA_BUSY      (0x00000001ul <<  2)
#define SP_STATUS_DMA_FULL      (0x00000001ul <<  3)
#define SP_STATUS_IO_FULL       (0x00000001ul <<  4)
#define SP_STATUS_SSTEP         (0x00000001ul <<  5)
#define SP_STATUS_INTR_BREAK    (0x00000001ul <<  6)
#define SP_STATUS_SIG0          (0x00000001ul <<  7)
#define SP_STATUS_SIG1          (0x00000001ul <<  8)
#define SP_STATUS_SIG2          (0x00000001ul <<  9)
#define SP_STATUS_SIG3          (0x00000001ul << 10)
#define SP_STATUS_SIG4          (0x00000001ul << 11)
#define SP_STATUS_SIG5          (0x00000001ul << 12)
#define SP_STATUS_SIG6          (0x00000001ul << 13)
#define SP_STATUS_SIG7          (0x00000001ul << 14)

#define NUMBER_OF_CP0_REGISTERS         16
extern pu32 CR[NUMBER_OF_CP0_REGISTERS];

extern void SP_DMA_READ(void);
extern void SP_DMA_WRITE(void);

extern u16 rwR_VCE(void);
extern void rwW_VCE(u16 VCE);

extern void MFC2(unsigned int rt, unsigned int vs, unsigned int e);
extern void MTC2(unsigned int rt, unsigned int vd, unsigned int e);
extern void CFC2(unsigned int rt, unsigned int rd);
extern void CTC2(unsigned int rt, unsigned int rd);

/*** Modern pseudo-operations (not real instructions, but nice shortcuts) ***/
extern void ULW(unsigned int rd, u32 addr);
extern void USW(unsigned int rs, u32 addr);

/*
 * The scalar unit controls the primary R4000 operations implementation,
 * which inherently includes interfacing with the vector unit under COP2.
 *
 * Although no scalar unit operations are computational vector operations,
 * several of them will access machine states shared with the vector unit.
 *
 * We will need access to the vector unit's vector register file and its
 * vector control register file used mainly for vector select instructions.
 */
#include "vu/select.h"

NOINLINE extern void res_S(void);

extern void SP_CP0_MF(unsigned int rt, unsigned int rd);

/*
 * example syntax (basically the same for all LWC2/SWC2 ops):
 * LTWV    $v0[0], -64($at)
 * SBV     $v0[9], 0xFFE($0)
 */
typedef void(*mwc2_func)(
    unsigned int vt,
    unsigned int element,
    signed int offset,
    unsigned int base
);

extern mwc2_func LWC2[2 * 8*2];
extern mwc2_func SWC2[2 * 8*2];

extern void res_lsw(
    unsigned int vt,
    unsigned int element,
    signed int offset,
    unsigned int base
);

/*** Scalar, Coprocessor Operations (vector unit, scalar cache transfers) ***/
extern void LBV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void LSV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void LLV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void LDV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void SBV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void SSV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void SLV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void SDV(unsigned vt, unsigned element, signed offset, unsigned base);

/*
 * Group II vector loads and stores:
 * PV and UV (As of RCP implementation, XV and ZV are reserved opcodes.)
 */
extern void LPV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void LUV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void SPV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void SUV(unsigned vt, unsigned element, signed offset, unsigned base);

/*
 * Group III vector loads and stores:
 * HV, FV, and AV (As of RCP implementation, AV opcodes are reserved.)
 */
extern void LHV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void LFV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void SHV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void SFV(unsigned vt, unsigned element, signed offset, unsigned base);

/*
 * Group IV vector loads and stores:
 * QV and RV
 */
extern void LQV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void LRV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void SQV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void SRV(unsigned vt, unsigned element, signed offset, unsigned base);

/*
 * Group V vector loads and stores
 * TV and SWV (As of RCP implementation, LTWV opcode was undesired.)
 */
extern void LTV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void SWV(unsigned vt, unsigned element, signed offset, unsigned base);
extern void STV(unsigned vt, unsigned element, signed offset, unsigned base);

NOINLINE extern void run_task(void);

#endif
