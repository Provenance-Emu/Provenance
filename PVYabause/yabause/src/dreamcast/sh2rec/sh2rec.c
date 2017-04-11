/*  Copyright 2010 Lawrence Sebald

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
*/

/* SH2 Dynarec Core (for SH4) */

#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <arch/cache.h>

#include "sh2core.h"
#include "sh2rec.h"
#include "sh2rec_htab.h"
#include "sh2int.h"

/* Registers */
#define R0  0
#define R1  1
#define R2  2
#define R3  3
#define R4  4
#define R5  5
#define R6  6
#define R7  7
#define R8  8
#define R9  9
#define R10 10
#define R11 11
#define R12 12
#define R13 13
#define R14 14
#define R15 15

/* Control Registers (use with emitSTC/emitLDC) */
#define R_SR    0
#define R_GBR   1
#define R_VBR   2

/* System Registers (use with emitSTS/emitLDS) */
#define R_MACH  0
#define R_MACL  1
#define R_PR    2

/* ALU Ops, to be used with the emitALU function */
#define OP_ADD      0x300C
#define OP_ADDC     0x300E
#define OP_AND      0x2009
#define OP_EXTSB    0x600E
#define OP_EXTSW    0x600F
#define OP_EXTUB    0x600C
#define OP_EXTUW    0x600D
#define OP_NEG      0x600B
#define OP_NEGC     0x600A
#define OP_NOT      0x6007
#define OP_OR       0x200B
#define OP_SUB      0x3008
#define OP_SUBC     0x300A
#define OP_SWAPB    0x6008
#define OP_SWAPW    0x6009
#define OP_XOR      0x200A
#define OP_XTRCT    0x200D

/* Shift/Rotate Ops, to be used with the emitSHIFT function */
#define OP_ROTCL    0x4024
#define OP_ROTCR    0x4025
#define OP_ROTL     0x4004
#define OP_ROTR     0x4005
#define OP_SHAL     0x4020
#define OP_SHAR     0x4021
#define OP_SHLL     0x4000
#define OP_SHLR     0x4001

/* Comparison Ops, to be used with the emitALU function */
#define OP_CMPEQ    0x3000
#define OP_CMPGE    0x3003
#define OP_CMPGT    0x3007
#define OP_CMPHI    0x3006
#define OP_CMPHS    0x3002
#define OP_CMPSTR   0x200C
#define OP_TST      0x2008

/* Multiplication ops, to be used with the emitALU function */
#define OP_DMULS    0x300D
#define OP_DMULU    0x3005
#define OP_MULL     0x0007
#define OP_MULS     0x200F
#define OP_MULU     0x200E

#ifdef SH2REC__DEBUG
#define EMIT_INST {\
    printf("%s\n", __PRETTY_FUNCTION__); \
    printf("Emitting %04x at %p\n", inst, (void *)b->ptr); \
    *b->ptr++ = inst; \
}
#else
#define EMIT_INST *b->ptr++ = inst
#endif

#ifdef SH2REC__DEBUG
#define EMIT_32 {\
    uint32_t *__ptr = (uint32_t *)b->ptr; \
    printf("%s\n", __PRETTY_FUNCTION__); \
    printf("Emitting %08x at %p\n", (unsigned int)v, (void *)__ptr); \
    *__ptr = v; \
    b->ptr += 2; \
}
#else
#define EMIT_32 uint32_t *__ptr = (uint32_t *)b->ptr; *__ptr = v; b->ptr += 2
#endif

static inline void emit16(sh2rec_block_t *b, uint16_t inst) {
    EMIT_INST;
}

static inline void emit32(sh2rec_block_t *b, uint32_t v) {
    EMIT_32;
}

static inline void emitMOV(sh2rec_block_t *b, int m, int n) {
    uint16_t inst = 0x6003 | (n << 8) | (m << 4);
    EMIT_INST;
}

static inline void emitMOVWI(sh2rec_block_t *b, int d, int n) {
    uint16_t inst = 0x9000 | (n << 8) | (d);
    EMIT_INST;
}

static inline void emitMOVLI(sh2rec_block_t *b, int d, int n) {
    uint16_t inst = 0xD000 | (n << 8) | (d);
    EMIT_INST;
}

static inline void emitMOVLS(sh2rec_block_t *b, int m, int n) {
    uint16_t inst = 0x2002 | (n << 8) | (m << 4);
    EMIT_INST;
}

static inline void emitMOVLL(sh2rec_block_t *b, int m, int n) {
    uint16_t inst = 0x6002 | (n << 8) | (m << 4);
    EMIT_INST;
}

static inline void emitMOVWM(sh2rec_block_t *b, int m, int n) {
    uint16_t inst = 0x2005 | (n << 8) | (m << 4);
    EMIT_INST;
}

static inline void emitMOVLM(sh2rec_block_t *b, int m, int n) {
    uint16_t inst = 0x2006 | (n << 8) | (m << 4);
    EMIT_INST;
}

static inline void emitMOVLP(sh2rec_block_t *b, int m, int n) {
    uint16_t inst = 0x6006 | (n << 8) | (m << 4);
    EMIT_INST;
}

static inline void emitMOVI(sh2rec_block_t *b, int imm, int n) {
    uint16_t inst = 0xE000 | (n << 8) | (imm & 0xFF);
    EMIT_INST;
}

static inline void emitMOVLL4(sh2rec_block_t *b, int m, int d, int n) {
    uint16_t inst = 0x5000 | (n << 8) | (m << 4) | (d);
    EMIT_INST;
}

static inline void emitMOVLS4(sh2rec_block_t *b, int m, int d, int n) {
    uint16_t inst = 0x1000 | (n << 8) | (m << 4) | (d);
    EMIT_INST;
}

static inline void emitMOVLLG(sh2rec_block_t *b, int imm) {
    uint16_t inst = 0xC600 | (imm & 0xFF);
    EMIT_INST;
}

static inline void emitMOVLSG(sh2rec_block_t *b, int imm) {
    uint16_t inst = 0xC200 | (imm & 0xFF);
    EMIT_INST;
}

static inline void emitMOVT(sh2rec_block_t *b, int n) {
    uint16_t inst = 0x0029 | (n << 8);
    EMIT_INST;
}

static inline void emitALU(sh2rec_block_t *b, int m, int n, uint16_t op) {
    uint16_t inst = (n << 8) | (m << 4) | op;
    EMIT_INST;
}

static inline void emitSHIFT(sh2rec_block_t *b, int n, uint16_t op) {
    uint16_t inst = (n << 8) | op;
    EMIT_INST;
}

static inline void emitADDI(sh2rec_block_t *b, int imm, int n) {
    uint16_t inst = 0x7000 | (n << 8) | (imm & 0xFF);
    EMIT_INST;
}

static inline void emitANDI(sh2rec_block_t *b, int imm) {
    uint16_t inst = 0xC900 | (imm & 0xFF);
    EMIT_INST;
}

static inline void emitORI(sh2rec_block_t *b, int imm) {
    uint16_t inst = 0xCB00 | (imm & 0xFF);
    EMIT_INST;
}

static inline void emitXORI(sh2rec_block_t *b, int imm) {
    uint16_t inst = 0xCA00 | (imm & 0xFF);
    EMIT_INST;
}

static inline void emitSHLL2(sh2rec_block_t *b, int n) {
    uint16_t inst = 0x4008 | (n << 8);
    EMIT_INST;
}

static inline void emitSHLL8(sh2rec_block_t *b, int n) {
    uint16_t inst = 0x4018 | (n << 8);
    EMIT_INST;
}

static inline void emitSHLL16(sh2rec_block_t *b, int n) {
    uint16_t inst = 0x4028 | (n << 8);
    EMIT_INST;
}

static inline void emitSHLR2(sh2rec_block_t *b, int n) {
    uint16_t inst = 0x4009 | (n << 8);
    EMIT_INST;
}

static inline void emitSHLR8(sh2rec_block_t *b, int n) {
    uint16_t inst = 0x4019 | (n << 8);
    EMIT_INST;
}

static inline void emitSHLR16(sh2rec_block_t *b, int n) {
    uint16_t inst = 0x4029 | (n << 8);
    EMIT_INST;
}

static inline void emitCMPIM(sh2rec_block_t *b, int imm) {
    uint16_t inst = 0x8800 | (imm & 0xFF);
    EMIT_INST;
}

static inline void emitCMPPL(sh2rec_block_t *b, int n) {
    uint16_t inst = 0x4015 | (n << 8);
    EMIT_INST;
}

static inline void emitCMPPZ(sh2rec_block_t *b, int n) {
    uint16_t inst = 0x4011 | (n << 8);
    EMIT_INST;
}

static inline void emitADDV(sh2rec_block_t *b, int m, int n) {
    uint16_t inst = 0x300F | (n << 8) | (m << 4);
    EMIT_INST;
}

static inline void emitSUBV(sh2rec_block_t *b, int m, int n) {
    uint16_t inst = 0x300B | (n << 8) | (m << 4);
    EMIT_INST;
}

static inline void emitLDS(sh2rec_block_t *b, int m, int sr) {
    uint16_t inst = 0x400A | (m << 8) | (sr << 4);
    EMIT_INST;
}

static inline void emitSTS(sh2rec_block_t *b, int sr, int n) {
    uint16_t inst = 0x000A | (n << 8) | (sr << 4);
    EMIT_INST;
}

static inline void emitLDC(sh2rec_block_t *b, int m, int sr) {
    uint16_t inst = 0x400E | (m << 8) | (sr << 4);
    EMIT_INST;
}

static inline void emitSTC(sh2rec_block_t *b, int sr, int n) {
    uint16_t inst = 0x0002 | (n << 8) | (sr << 4);
    EMIT_INST;
}

static inline void emitDT(sh2rec_block_t *b, int n) {
    uint16_t inst = 0x4010 | (n << 8);
    EMIT_INST;
}

static inline void emitTSTI(sh2rec_block_t *b, int imm) {
    uint16_t inst = 0xC800 | (imm & 0xFF);
    EMIT_INST;
}

static inline void emitBRA(sh2rec_block_t *b, int d) {
    uint16_t inst = 0xA000 | (d);
    EMIT_INST;
}

static inline void emitDIV0S(sh2rec_block_t *b, int m, int n) {
    uint16_t inst = 0x2007 | (n << 8) | (m << 4);
    EMIT_INST;
}

static inline void emitDIV1(sh2rec_block_t *b, int m, int n) {
    uint16_t inst = 0x3004 | (n << 8) | (m << 4);
    EMIT_INST;
}

static inline void emitRTS(sh2rec_block_t *b) {
    uint16_t inst = 0x000B;
    EMIT_INST;
}

static inline void emitNOP(sh2rec_block_t *b) {
    uint16_t inst = 0x0009;
    EMIT_INST;
}

static inline void emitJSR(sh2rec_block_t *b, int m) {
    uint16_t inst = 0x400B | (m << 8);
    EMIT_INST;
}

static inline void emitMACL(sh2rec_block_t *b, int m, int n) {
    uint16_t inst = 0x000F | (n << 8) | (m << 4);
    EMIT_INST;
}

static inline void emitMACW(sh2rec_block_t *b, int m, int n) {
    uint16_t inst = 0x400F | (n << 8) | (m << 4);
    EMIT_INST;
}

static inline void emitCLRMAC(sh2rec_block_t *b) {
    uint16_t inst = 0x0028;
    EMIT_INST;
}

static inline void emitBF(sh2rec_block_t *b, int disp) {
    uint16_t inst = 0x8B00 | (disp & 0xFF);
    EMIT_INST;
}

static inline void emitBT(sh2rec_block_t *b, int disp) {
    uint16_t inst = 0x8900 | (disp & 0xFF);
    EMIT_INST;
}

static inline void generateALUOP(uint16_t inst, sh2rec_block_t *b, int op) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitMOVLL4(b, R8, regm, R3);    /* R3 <- sh2[Rm] */
    emitALU(b, R3, R2, op);         /* R2 <- R2 o R3 */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */

    ++b->cycles;                    /* 1 Cycle */
}

static inline void generateSHIFT(uint16_t inst, sh2rec_block_t *b, int op) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitSHIFT(b, R2, op);           /* R2 <- R2 op */
    emitSHIFT(b, R0, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
}

static inline void generateCOMP(uint16_t inst, sh2rec_block_t *b, int op) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitMOVLL4(b, R8, regm, R3);    /* R3 <- sh2[Rm] */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitALU(b, R3, R2, op);         /* R2 op R3 */
    emitSHIFT(b, R0, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
}

static void generateADD(uint16_t inst, sh2rec_block_t *b) {
    generateALUOP(inst, b, OP_ADD);
    b->pc += 2;
}

static void generateADDI(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int imm = INSTRUCTION_CD(inst);

    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitADDI(b, imm, R2);           /* R2 <- R2 + #imm */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateADDC(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitMOVLL4(b, R8, regm, R3);    /* R3 <- sh2[Rm] */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitALU(b, R3, R2, OP_ADDC);    /* R2 = R2 + R3 + T (carry to T) */
    emitSHIFT(b, R0, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateADDV(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitMOVLL4(b, R8, regm, R3);    /* R3 <- sh2[Rm] */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitADDV(b, R3, R2);            /* R2 = R2 + R3 (overflow to T Bit) */
    emitSHIFT(b, R0, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateAND(uint16_t inst, sh2rec_block_t *b) {
    generateALUOP(inst, b, OP_AND);
    b->pc += 2;
}

static void generateANDI(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);

    emitMOVLL4(b, R8, 0, R0);       /* R0 <- sh2[R0] */
    emitANDI(b, imm);               /* R0 <- R0 & #imm */
    emitMOVLS4(b, R0, 0, R8);       /* sh2[R0] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateANDM(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLLG(b, 17);              /* R0 <- sh2[GBR] */
    emitMOVLL4(b, R8, 0, R4);       /* R4 <- sh2[R0] */
    emitMOVLL4(b, R9, 0, R1);       /* R1 <- MappedMemoryReadByte */
    emitALU(b, R0, R4, OP_ADD);     /* R4 <- R4 + R0 */
    emitJSR(b, R1);                 /* Call MappedMemoryReadByte */
    emitMOVLM(b, R4, R15);          /* Push R4 on the stack (delay slot) */
    emitMOVLL4(b, R9, 3, R1);       /* R1 <- MappedMemoryWriteByte */
    emitANDI(b, imm);               /* R0 <- R0 & #imm */
    emitMOVLP(b, R15, R4);          /* Pop R4 off the stack */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteByte */
    emitMOV(b, R0, R5);             /* R5 <- R0 (delay slot) */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    b->cycles += 3;                 /* 3 Cycles */
    b->pc += 2;
}

static void generateBF(uint16_t inst, sh2rec_block_t *b) {
    int disp = INSTRUCTION_CD(inst);
    uint32_t val = b->pc + 2;

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLI(b, 4, R2);            /* R2 <- sh2[PC] + 2 */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitMOVI(b, 0, R0);             /* R0 <- 0 */
    emitBT(b, 2);                   /* Branch around the addition if needed */
    emitMOVI(b, disp, R0);          /* R0 <- displacement */
    emitSHIFT(b, R0, OP_SHLL);      /* R0 <- R0 << 1 */
    emitADDI(b, 2, R0);             /* R0 <- R0 + 2 */
    emitRTS(b);                     /* Return to sender! */
    emitALU(b, R2, R0, OP_ADD);     /* R0 <- R0 + R2 (delay slot) */
    if(((uint32_t)b->ptr) & 0x03)
        emit16(b, 0);               /* Padding if we need it */
    emit32(b, val);                 /* The next PC value (if not taken) */

    b->cycles += 2;                 /* 2 Cycles (if not taken) */
    /* XXXX: Handle taken case cycle difference */
}

static void generateBFS(uint16_t inst, sh2rec_block_t *b) {
    int disp = INSTRUCTION_CD(inst);
    uint32_t val = b->pc + 4;
    int n = (((uint32_t)b->ptr) & 0x03) ? 3 : 4;
    
    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLI(b, n, R2);            /* R2 <- sh2[PC] + 4 */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitMOVI(b, 0, R0);             /* R0 <- 0 */
    emitBT(b, 1);                   /* Branch around the addition if needed */
    emitMOVI(b, disp, R0);          /* R0 <- displacement */
    emitSHIFT(b, R0, OP_SHLL);      /* R0 <- R0 << 1 */

    if(((uint32_t)b->ptr) & 0x03) {
        emitBRA(b, 3);              /* Branch around the constant */
        emitALU(b, R2, R0, OP_ADD); /* R0 <- R0 + R2 (delay slot) */
        emit16(b, 0);               /* Padding since we need it */
    }
    else {
        emitBRA(b, 2);              /* Branch around the constant */
        emitALU(b, R2, R0, OP_ADD); /* R0 <- R0 + R2 (delay slot) */
    }

    emit32(b, val);                 /* The next PC value (if not taken) */
    emitMOVLM(b, R0, R15);          /* Push the next PC on the stack */

    /* Deal with the delay slot here */
    b->pc += 2;
    sh2rec_rec_inst(b, 1);

    emitRTS(b);                     /* Return to sender! */
    emitMOVLP(b, R15, R0);          /* Pop the next PC (delay slot) */

    ++b->cycles;                    /* 1 Cycle (if not taken) */
    /* XXXX: Handle taken case cycle difference */
}

static void generateBRA(uint16_t inst, sh2rec_block_t *b) {
    int disp = INSTRUCTION_BCD(inst);
    int32_t val;

    if(disp & 0x00000800) {
        disp |= 0xFFFFF000;
    }

    val = b->pc + 4 + (disp << 1);

    emitMOVLI(b, 1, R2);            /* R2 <- sh2[PC] + 4 + disp */

    if(((uint32_t)b->ptr) & 0x03) {
        emitBRA(b, 3);              /* Branch around the constant */
        emitMOVLM(b, R2, R15);      /* Push the next PC (delay slot) */
        emit16(b, 0);               /* Padding since we need it */
    }
    else {
        emitBRA(b, 2);              /* Branch around the constant */
        emitMOVLM(b, R2, R15);      /* Push the next PC (delay slot) */
    }

    emit32(b, (uint32_t )val);      /* The next PC */

    /* Deal with the delay slot */
    b->pc += 2;
    sh2rec_rec_inst(b, 1);

    emitRTS(b);                     /* Return to sender! */
    emitMOVLP(b, R15, R0);          /* Pop the next PC (delay slot) */

    b->cycles += 2;                 /* 2 Cycles */
}

static void generateBRAF(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);
    uint32_t val = b->pc + 4;

    if(((uint32_t)b->ptr) & 0x03) {
        emitMOVLI(b, 2, R0);        /* R0 <- sh2[PC] + 4 */
        emitMOVLL4(b, R8, regm, R2);/* R2 <- sh2[Rm] */
        emitBRA(b, 3);              /* Branch around the constant */
        emitALU(b, R0, R2, OP_ADD); /* R2 <- R0 + R2 (delay slot) */
        emit16(b, 0);               /* Padding since we need it */
    }
    else {
        emitMOVLI(b, 1, R0);        /* R0 <- sh2[PC] + 4 */
        emitMOVLL4(b, R8, regm, R2);/* R2 <- sh2[Rm] */
        emitBRA(b, 2);              /* Branch around the constant */
        emitALU(b, R0, R2, OP_ADD); /* R2 <- R0 + R2 (delay slot) */
    }

    emit32(b, val);                 /* The value to use as the base for PC */
    emitMOVLM(b, R2, R15);          /* Push the next PC */

    /* Deal with the delay slot */
    b->pc += 2;
    sh2rec_rec_inst(b, 1);

    emitRTS(b);                     /* Return to sender! */
    emitMOVLP(b, R15, R0);          /* Pop the next PC (delay slot) */

    b->cycles += 2;                 /* 2 Cycles */
}

static void generateBSR(uint16_t inst, sh2rec_block_t *b) {
    int disp = INSTRUCTION_BCD(inst);
    int32_t val;
    int32_t val2 = b->pc + 4;

    if(disp & 0x00000800) {
        disp |= 0xFFFFF000;
    }

    val = b->pc + 4 + (disp << 1);

    if(((uint32_t)b->ptr) & 0x03) {
        emitMOVLI(b, 2, R2);        /* R2 <- sh2[PC] + 4 + disp */
        emitMOVLI(b, 2, R0);        /* R0 <- sh2[PC] + 4 */
        emitBRA(b, 5);              /* Branch around the constant */
        emitMOVLM(b, R2, R15);      /* Push the next PC (delay slot) */
        emit16(b, 0);               /* Padding since we need it */
    }
    else {
        emitMOVLI(b, 1, R2);        /* R2 <- sh2[PC] + 4 + disp */
        emitMOVLI(b, 2, R0);        /* R0 <- sh2[PC] + 4 */
        emitBRA(b, 4);              /* Branch around the constant */
        emitMOVLM(b, R2, R15);      /* Push the next PC (delay slot) */
    }

    emit32(b, (uint32_t)val);       /* The next PC */
    emit32(b, (uint32_t)val2);      /* The value for PR */
    emitMOVLSG(b, 21);              /* sh2[PR] <- R0 */

    /* Deal with the delay slot */
    b->pc += 2;
    sh2rec_rec_inst(b, 1);

    emitRTS(b);                     /* Return to sender! */
    emitMOVLP(b, R15, R0);          /* Pop the next PC (delay slot) */

    b->cycles += 2;                 /* 2 Cycles */
}

static void generateBSRF(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);
    uint32_t val = b->pc + 4;

    emitMOVLI(b, 1, R0);            /* R0 <- sh2[PC] + 4 */

    if(((uint32_t)b->ptr) & 0x03) {
        emitBRA(b, 3);              /* Branch around the constant */
        emitMOVLL4(b, R8, regm, R2);/* R2 <- sh2[Rm] (delay slot) */
        emit16(b, 0);               /* Padding since we need it */
    }
    else {
        emitBRA(b, 2);              /* Branch around the constant */
        emitMOVLL4(b, R8, regm, R2);/* R2 <- sh2[Rm] (delay slot) */
    }

    emit32(b, val);                 /* The value to put in PR */
    emitALU(b, R0, R2, OP_ADD);     /* R2 <- R0 + R2 (branch target) */
    emitMOVLSG(b, 21);              /* sh2[PR] <- R0 */
    emitMOVLM(b, R2, R15);          /* Push the next PC */

    /* Deal with the delay slot */
    b->pc += 2;
    sh2rec_rec_inst(b, 1);

    emitRTS(b);                     /* Return to sender! */
    emitMOVLP(b, R15, R0);          /* Pop the next PC (delay slot) */

    b->cycles += 2;                 /* 2 Cycles */
}

static void generateBT(uint16_t inst, sh2rec_block_t *b) {
    int disp = INSTRUCTION_CD(inst);
    uint32_t val = b->pc + 2;

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLI(b, 4, R2);            /* R2 <- sh2[PC] + 4 */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitMOVI(b, 0, R0);             /* R0 <- 0 */
    emitBF(b, 2);                   /* Branch around the addition if needed */
    emitMOVI(b, disp, R0);          /* R0 <- displacement */
    emitSHIFT(b, R0, OP_SHLL);      /* R0 <- R0 << 1 */
    emitADDI(b, 2, R0);             /* R0 <- R0 + 2 */
    emitRTS(b);                     /* Return to sender! */
    emitALU(b, R2, R0, OP_ADD);     /* R0 <- R0 + R2 (delay slot) */
    if(((uint32_t)b->ptr) & 0x03)
        emit16(b, 0);               /* Padding if we need it */
    emit32(b, val);                 /* The next PC value (if not taken) */

    b->cycles += 2;                 /* 2 Cycles (if not taken) */
    /* XXXX: Handle taken case cycle difference */
}

static void generateBTS(uint16_t inst, sh2rec_block_t *b) {
    int disp = INSTRUCTION_CD(inst);
    uint32_t val = b->pc + 4;
    int n = (((uint32_t)b->ptr) & 0x03) ? 3 : 4;

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLI(b, n, R2);            /* R2 <- sh2[PC] + 2 */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitMOVI(b, 0, R0);             /* R0 <- 0 */
    emitBF(b, 1);                   /* Branch around the addition if needed */
    emitMOVI(b, disp, R0);          /* R0 <- displacement */
    emitSHIFT(b, R0, OP_SHLL);      /* R0 <- R0 << 1 */

    if(((uint32_t)b->ptr) & 0x03) {
        emitBRA(b, 3);              /* Branch around the constant */
        emitALU(b, R2, R0, OP_ADD); /* R0 <- R0 + R2 (delay slot) */
        emit16(b, 0);               /* Padding since we need it */
    }
    else {
        emitBRA(b, 2);              /* Branch around the constant */
        emitALU(b, R2, R0, OP_ADD); /* R0 <- R0 + R2 (delay slot) */
    }

    emit32(b, val);                 /* The next PC value (if not taken) */
    emitMOVLM(b, R0, R15);          /* Push the next PC */

    /* Deal with the delay slot */
    b->pc += 2;
    sh2rec_rec_inst(b, 1);

    emitRTS(b);                     /* Return to sender! */
    emitMOVLP(b, R15, R0);          /* Pop the next PC (delay slot) */

    ++b->cycles;                    /* 1 Cycle (if not taken) */
    /* XXXX: Handle taken case cycle difference */
}

static void generateCLRMAC(uint16_t inst, sh2rec_block_t *b) {
    emitCLRMAC(b);                  /* MACL/MACH <- 0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateCLRT(uint16_t inst, sh2rec_block_t *b) {
    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVI(b, 0xFE, R1);          /* R1 <- 0xFFFFFFFE */
    emitALU(b, R3, R0, OP_AND);     /* Clear T bit */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateCMPEQ(uint16_t inst, sh2rec_block_t *b) {
    generateCOMP(inst, b, OP_CMPEQ);
    b->pc += 2;
}

static void generateCMPGE(uint16_t inst, sh2rec_block_t *b) {
    generateCOMP(inst, b, OP_CMPGE);
    b->pc += 2;
}

static void generateCMPGT(uint16_t inst, sh2rec_block_t *b) {
    generateCOMP(inst, b, OP_CMPGT);
    b->pc += 2;
}

static void generateCMPHI(uint16_t inst, sh2rec_block_t *b) {
    generateCOMP(inst, b, OP_CMPHI);
    b->pc += 2;
}

static void generateCMPHS(uint16_t inst, sh2rec_block_t *b) {
    generateCOMP(inst, b, OP_CMPHS);
    b->pc += 2;
}

static void generateCMPSTR(uint16_t inst, sh2rec_block_t *b) {
    generateCOMP(inst, b, OP_CMPSTR);
    b->pc += 2;
}

static void generateCMPPL(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitCMPPL(b, R2);               /* cmp/pl R2 */
    emitSHIFT(b, R0, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateCMPPZ(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitCMPPZ(b, R2);               /* cmp/pz R2 */
    emitSHIFT(b, R0, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateCMPIM(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOV(b, R0, R2);             /* R2 <- R0 */
    emitMOVLL4(b, R8, 0, R0);       /* R0 <- sh2[R0] */
    emitSHIFT(b, R2, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitCMPIM(b, imm);              /* cmp/eq R0, #imm */
    emitSHIFT(b, R2, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitMOV(b, R2, R0);             /* R0 <- R2 */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateDIV0S(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitMOVI(b, 0x03, R4);          /* R4 <- 0x03 */
    emitANDI(b, 0xF2);              /* Clear M, Q, and T */
    emitMOVLL4(b, R8, regm, R3);    /* R3 <- sh2[Rm] */
    emitSHLL8(b, R4);               /* R4 <<= 8 */
    emitSHIFT(b, R0, OP_SHLR);      /* Chop off the T from the SH2 reg */
    emitDIV0S(b, R3, R2);           /* div0s to grab the M, Q, T bits needed */
    emitSTC(b, R_SR, R5);           /* Save SR to R5 */
    emitALU(b, R4, R5, OP_AND);     /* Grab M, Q from the SR */
    emitSHIFT(b, R0, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitALU(b, R5, R0, OP_OR);      /* Save M, Q into the SH2 reg */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateDIV0U(uint16_t inst, sh2rec_block_t *b) {
    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitANDI(b, 0xF2);              /* Mask off M, Q, and T bits */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateDIV1(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitMOVI(b, 0x03, R4);          /* R4 <- 0x03 */
    emitSHLL8(b, R4);               /* R4 <<= 8 */
    emitMOVLL4(b, R8, regm, R3);    /* R3 <- sh2[Rm] */
    emitMOV(b, R4, R6);             /* R6 <- R4 */
    emitALU(b, R0, R6, OP_AND);     /* Grab SH2 M and Q bits */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T in place */
    emitSTC(b, R_SR, R5);           /* Save SR to R5 */
    emitALU(b, R4, R7, OP_NOT);     /* Set up the mask to clear M and Q */
    emitALU(b, R7, R5, OP_AND);     /* Clear M, Q */
    emitALU(b, R6, R5, OP_OR);      /* Put SH2's M and Q in place */
    emitLDC(b, R5, R_SR);           /* Put the modified SR in place */
    emitDIV1(b, R3, R2);            /* Do the division! */
    emitSTC(b, R_SR, R5);           /* Save updated SR to R5 */
    emitALU(b, R4, R5, OP_AND);     /* Grab M and Q from the SR */
    emitSHIFT(b, R0, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */
    emitANDI(b, 0xF3);              /* Clear M and Q from the SH2 reg */
    emitALU(b, R5, R0, OP_OR);      /* Save M and Q into the SH2 reg */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateDMULS(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitMOVLL4(b, R8, regm, R3);    /* R3 <- sh2[Rm] */
    emitALU(b, R3, R2, OP_DMULS);   /* MACH/MACL <- (s32)R2 * (s32)R3 */

    b->cycles += 2;                 /* 2 Cycles */
    b->pc += 2;
}

static void generateDMULU(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitMOVLL4(b, R8, regm, R3);    /* R3 <- sh2[Rm] */
    emitALU(b, R3, R2, OP_DMULU);   /* MACH/MACL <- (u32)R2 * (u32)R3 */

    b->cycles += 2;                 /* 2 Cycles */
    b->pc += 2;
}

static void generateDT(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitDT(b, R2);                  /* R2 = R2 - 1 (T Bit = non-zero) */
    emitSHIFT(b, R0, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateEXTSB(uint16_t inst, sh2rec_block_t *b) {
    generateALUOP(inst, b, OP_EXTSB);
    b->pc += 2;
}

static void generateEXTSW(uint16_t inst, sh2rec_block_t *b) {
    generateALUOP(inst, b, OP_EXTSW);
    b->pc += 2;
}

static void generateEXTUB(uint16_t inst, sh2rec_block_t *b) {
    generateALUOP(inst, b, OP_EXTUB);
    b->pc += 2;
}

static void generateEXTUW(uint16_t inst, sh2rec_block_t *b) {
    generateALUOP(inst, b, OP_EXTUW);
    b->pc += 2;
}

static void generateJMP(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);

    emitMOVLL4(b, R8, regm, R0);    /* Grab the next PC value */
    emitMOVLM(b, R0, R15);          /* Push the next PC on the stack */

    /* Deal with the delay slot */
    b->pc += 2;
    sh2rec_rec_inst(b, 1);

    emitRTS(b);                     /* Return to sender! */
    emitMOVLP(b, R15, R0);          /* Pop the next PC (delay slot) */

    b->cycles += 2;                 /* 2 Cycles */
}

static void generateJSR(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);
    uint32_t val = b->pc + 4;

    emitMOVLI(b, 1, R0);            /* R0 <- sh2[PC] + 4 */

    if(((uint32_t)b->ptr) & 0x03) {
        emitBRA(b, 3);              /* Branch around the constant */
        emitMOVLL4(b, R8, regm, R2);/* R2 <- sh2[Rm] (delay slot) */
        emit16(b, 0);               /* Padding since we need it */
    }
    else {
        emitBRA(b, 2);              /* Branch around the constant */
        emitMOVLL4(b, R8, regm, R2);/* R2 <- sh2[Rm] (delay slot) */
    }

    emit32(b, val);                 /* The value to put in PR */
    emitMOVLM(b, R2, R15);          /* Push the next PC */
    emitMOVLSG(b, 21);              /* sh2[PR] <- R0 */

    /* Deal with the delay slot */
    b->pc += 2;
    sh2rec_rec_inst(b, 1);

    emitRTS(b);                     /* Return to sender! */
    emitMOVLP(b, R15, R0);          /* Pop the next PC (delay slot) */

    b->cycles += 2;                 /* 2 Cycles */
}

static void generateLDCSR(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);

    emitMOVWI(b, 2, R2);            /* R2 <- 0x03F3 */
    emitMOVLL4(b, R8, regm, R0);    /* R0 <- sh2[Rm] */
    emitBRA(b, 1);                  /* Jump beyond the constant */
    emitALU(b, R2, R0, OP_AND);     /* R0 <- R0 & R2 (delay slot) */
    emit16(b, 0x03F3);              /* 0x03F3, grabbed by the emitMOVWI */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateLDCGBR(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);

    emitMOVLL4(b, R8, regm, R0);    /* R0 <- sh2[Rm] */
    emitMOVLSG(b, 17);              /* sh2[GBR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateLDCVBR(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);

    emitMOVLL4(b, R8, regm, R0);    /* R0 <- sh2[Rm] */
    emitMOVLSG(b, 18);              /* sh2[VBR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateLDCMSR(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);

    emitMOVLL4(b, R9, 2, R0);       /* R0 <- MappedMemoryReadLong */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVI(b, 4, R1);             /* R1 <- 4 */
    emitALU(b, R4, R1, OP_ADD);     /* R1 <- R4 + R1 */
    emitJSR(b, R0);                 /* Call MappedMemoryReadLong */
    emitMOVLS4(b, R1, regm, R8);    /* sh2[Rm] <- R1 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVWI(b, 2, R2);            /* R2 <- 0x03F3 */
    emitBRA(b, 1);                  /* Jump beyond the constant */
    emitALU(b, R2, R0, OP_AND);     /* R0 <- R0 & R2 (delay slot) */
    emit16(b, 0x03F3);              /* 0x03F3, grabbed by the emitMOVWI */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    b->cycles += 3;                 /* 3 Cycles */
    b->pc += 2;
}

static void generateLDCMGBR(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);

    emitMOVLL4(b, R9, 2, R0);       /* R0 <- MappedMemoryReadLong */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVI(b, 4, R1);             /* R1 <- 4 */
    emitALU(b, R4, R1, OP_ADD);     /* R1 <- R4 + R1 */
    emitJSR(b, R0);                 /* Call MappedMemoryReadLong */
    emitMOVLS4(b, R1, regm, R8);    /* sh2[Rm] <- R1 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLSG(b, 17);              /* sh2[GBR] <- R0 */

    b->cycles += 3;                 /* 3 Cycles */
    b->pc += 2;
}

static void generateLDCMVBR(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);

    emitMOVLL4(b, R9, 2, R0);       /* R0 <- MappedMemoryReadLong */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVI(b, 4, R1);             /* R1 <- 4 */
    emitALU(b, R4, R1, OP_ADD);     /* R1 <- R4 + R1 */
    emitJSR(b, R0);                 /* Call MappedMemoryReadLong */
    emitMOVLS4(b, R1, regm, R8);    /* sh2[Rm] <- R1 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLSG(b, 18);              /* sh2[VBR] <- R0 */

    b->cycles += 3;                 /* 3 Cycles */
    b->pc += 2;
}

static void generateLDSMACH(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);

    emitMOVLL4(b, R8, regm, R0);    /* R0 <- sh2[Rm] */
    emitLDS(b, R0, R_MACH);         /* MACH <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateLDSMACL(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);

    emitMOVLL4(b, R8, regm, R0);    /* R0 <- sh2[Rm] */
    emitLDS(b, R0, R_MACL);         /* MACL <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateLDSPR(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);

    emitMOVLL4(b, R8, regm, R0);    /* R0 <- sh2[Rm] */
    emitMOVLSG(b, 21);              /* sh2[PR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateLDSMMACH(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);

    emitMOVLL4(b, R9, 2, R0);       /* R0 <- MappedMemoryReadLong */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVI(b, 4, R1);             /* R1 <- 4 */
    emitALU(b, R4, R1, OP_ADD);     /* R1 <- R4 + R1 */
    emitJSR(b, R0);                 /* Call MappedMemoryReadLong */
    emitMOVLS4(b, R1, regm, R8);    /* sh2[Rm] <- R1 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitLDS(b, R0, R_MACH);         /* MACH <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateLDSMMACL(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);

    emitMOVLL4(b, R9, 2, R0);       /* R0 <- MappedMemoryReadLong */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVI(b, 4, R1);             /* R1 <- 4 */
    emitALU(b, R4, R1, OP_ADD);     /* R1 <- R4 + R1 */
    emitJSR(b, R0);                 /* Call MappedMemoryReadLong */
    emitMOVLS4(b, R1, regm, R8);    /* sh2[Rm] <- R1 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitLDS(b, R0, R_MACL);         /* MACL <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateLDSMPR(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_B(inst);

    emitMOVLL4(b, R9, 2, R0);       /* R0 <- MappedMemoryReadLong */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVI(b, 4, R1);             /* R1 <- 4 */
    emitALU(b, R4, R1, OP_ADD);     /* R1 <- R4 + R1 */
    emitJSR(b, R0);                 /* Call MappedMemoryReadLong */
    emitMOVLS4(b, R1, regm, R8);    /* sh2[Rm] <- R1 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLSG(b, 21);              /* sh2[PR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMACL(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVLL4(b, R9, 2, R0);       /* R0 <- MappedMemoryReadLong */
    emitADDI(b, 4, R4);             /* R4 <- R4 + 4 */
    emitMOVLS4(b, R4, regm, R8);    /* sh2[Rm] <- R4 */
    emitJSR(b, R0);                 /* Call MappedMemoryReadLong */
    emitADDI(b, -4, R4);            /* R4 <- R4 - 4 (delay slot) */
    emitMOVLM(b, R0, R15);          /* Push R0 onto the stack */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitMOVLL4(b, R9, 2, R0);       /* R0 <- MappedMemoryReadLong */
    emitADDI(b, 4, R4);             /* R4 <- R4 + 4 */
    emitMOVLS4(b, R4, regn, R8);    /* sh2[Rn] <- R4 */
    emitJSR(b, R0);                 /* Call MappedMemoryReadLong */
    emitADDI(b, -4, R4);            /* R4 <- R4 - 4 (delay slot) */
    emitSTC(b, R_SR, R2);           /* R2 <- SR */
    emitMOVI(b, 0xFD, R3);          /* R3 <- 0xFFFFFFFD */
    emitMOVLM(b, R0, R15);          /* Push R0 onto the stack */
    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitALU(b, R2, R3, OP_AND);     /* R3 <- R2 & R3 (Mask out S Bit) */
    emitANDI(b, 0x02);              /* R0 <- R0 & 0x02 (S Bit) */
    emitALU(b, R0, R3, OP_OR);      /* R3 <- R0 | R3 (Put SH2 S Bit in) */
    emitLDC(b, R3, R_SR);           /* SR <- R3 */
    emitMACL(b, R15, R15);          /* Perform the MAC.L */
    emitLDC(b, R2, R_SR);           /* SR <- R2 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    b->cycles += 3;                 /* 3 Cycles */
    b->pc += 2;
}

static void generateMACW(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVLL4(b, R9, 1, R0);       /* R0 <- MappedMemoryReadWord */
    emitADDI(b, 2, R4);             /* R4 <- R4 + 2 */
    emitMOVLS4(b, R4, regm, R8);    /* sh2[Rm] <- R4 */
    emitJSR(b, R0);                 /* Call MappedMemoryReadWord */
    emitADDI(b, -2, R4);            /* R4 <- R4 - 2 (delay slot) */
    emitMOVWM(b, R0, R15);          /* Push R0 onto the stack */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitMOVLL4(b, R9, 1, R0);       /* R0 <- MappedMemoryReadWord */
    emitADDI(b, 2, R4);             /* R4 <- R4 + 2 */
    emitMOVLS4(b, R4, regn, R8);    /* sh2[Rn] <- R4 */
    emitJSR(b, R0);                 /* Call MappedMemoryReadWord */
    emitADDI(b, -2, R4);            /* R4 <- R4 - 2 (delay slot) */
    emitMOVWM(b, R0, R15);          /* Push R0 onto the stack */
    emitSTC(b, R_SR, R2);           /* R2 <- SR */
    emitMOVI(b, 0xFD, R3);          /* R3 <- 0xFFFFFFFD */
    emitMOVLM(b, R0, R15);          /* Push R0 onto the stack */
    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitALU(b, R2, R3, OP_AND);     /* R3 <- R2 & R3 (Mask out S Bit) */
    emitANDI(b, 0x02);              /* R0 <- R0 & 0x02 (S Bit) */
    emitALU(b, R0, R3, OP_OR);      /* R3 <- R0 | R3 (Put SH2 S Bit in) */
    emitLDC(b, R3, R_SR);           /* SR <- R3 */
    emitMACW(b, R15, R15);          /* Perform the MAC.W */
    emitLDC(b, R2, R_SR);           /* SR <- R2 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    b->cycles += 3;                 /* 3 Cycles */
    b->pc += 2;
}

static void generateMOV(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R8, regm, R2);    /* R2 <- sh2[Rm] */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVBS(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R9, 3, R0);       /* R0 <- MappedMemoryWriteByte */
    emitMOVLL4(b, R8, regm, R5);    /* R5 <- sh2[Rm] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R0);                 /* Call MappedMemoryWriteByte */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVWS(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R9, 4, R0);       /* R0 <- MappedMemoryWriteWord */
    emitMOVLL4(b, R8, regm, R5);    /* R5 <- sh2[Rm] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R0);                 /* Call MappedMemoryWriteWord */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVLS(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R9, 5, R0);       /* R0 <- MappedMemoryWriteLong */
    emitMOVLL4(b, R8, regm, R5);    /* R5 <- sh2[Rm] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R0);                 /* Call MappedMemoryWriteLong */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVBL(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R9, 0, R0);       /* R0 <- MappedMemoryReadByte */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R0);                 /* Call MappedMemoryReadByte */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitALU(b, R0, R0, OP_EXTSB);   /* Sign extend read byte */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- read byte */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVWL(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R9, 1, R0);       /* R0 <- MappedMemoryReadWord */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R0);                 /* Call MappedMemoryReadWord */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitALU(b, R0, R0, OP_EXTSW);   /* Sign extend read word */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- read word */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVLL(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R9, 2, R0);       /* R0 <- MappedMemoryReadLong */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R0);                 /* Call MappedMemoryReadLong */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- read long */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVBM(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R8, regm, R5);    /* R5 <- sh2[Rm] */
    emitMOVLL4(b, R9, 3, R0);       /* R0 <- MappedMemoryWriteByte */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitADDI(b, -1, R4);            /* R4 -= 1 */
    emitJSR(b, R0);                 /* Call MappedMemoryWriteByte */
    emitMOVLS4(b, R4, regn, R8);    /* sh2[Rn] <- R4 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVWM(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R8, regm, R5);    /* R5 <- sh2[Rm] */
    emitMOVLL4(b, R9, 4, R0);       /* R0 <- MappedMemoryWriteWord */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitADDI(b, -2, R4);            /* R4 -= 2 */
    emitJSR(b, R0);                 /* Call MappedMemoryWriteWord */
    emitMOVLS4(b, R4, regn, R8);    /* sh2[Rn] <- R4 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVLM(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R8, regm, R5);    /* R5 <- sh2[Rm] */
    emitMOVLL4(b, R9, 5, R0);       /* R0 <- MappedMemoryWriteLong */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitADDI(b, -4, R4);            /* R4 -= 4 */
    emitJSR(b, R0);                 /* Call MappedMemoryWriteLong */
    emitMOVLS4(b, R4, regn, R8);    /* sh2[Rn] <- R4 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVBP(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R9, 0, R0);       /* R0 <- MappedMemoryReadByte */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVI(b, 1, R1);             /* R1 <- 1 */
    emitALU(b, R4, R1, OP_ADD);     /* R1 <- R4 + R1 */
    emitJSR(b, R0);                 /* Call MappedMemoryReadByte */
    emitMOVLS4(b, R1, regm, R8);    /* sh2[Rm] <- R1 */
    emitALU(b, R0, R0, OP_EXTSB);   /* Sign extend read byte */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- read byte */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVWP(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R9, 1, R0);       /* R0 <- MappedMemoryReadWord */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVI(b, 2, R1);             /* R1 <- 2 */
    emitALU(b, R4, R1, OP_ADD);     /* R1 <- R4 + R1 */
    emitJSR(b, R0);                 /* Call MappedMemoryReadWord */
    emitMOVLS4(b, R1, regm, R8);    /* sh2[Rm] <- R1 */
    emitALU(b, R0, R0, OP_EXTSW);   /* Sign extend read word */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- read word */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVLP(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R9, 2, R0);       /* R0 <- MappedMemoryReadLong */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVI(b, 4, R1);             /* R1 <- 4 */
    emitALU(b, R4, R1, OP_ADD);     /* R1 <- R4 + R1 */
    emitJSR(b, R0);                 /* Call MappedMemoryReadLong */
    emitMOVLS4(b, R1, regm, R8);    /* sh2[Rm] <- R1 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- read long */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVBS0(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R8, regm, R5);    /* R5 <- sh2[Rm] */
    emitMOVLL4(b, R8, 0, R1);       /* R1 <- sh2[R0] */
    emitMOVLL4(b, R9, 3, R0);       /* R0 <- MappedMemoryWriteByte */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitJSR(b, R0);                 /* Call MappedMemoryWriteByte */
    emitALU(b, R1, R4, OP_ADD);     /* R4 <- R4 + R1 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVWS0(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R8, regm, R5);    /* R5 <- sh2[Rm] */
    emitMOVLL4(b, R8, 0, R1);       /* R1 <- sh2[R0] */
    emitMOVLL4(b, R9, 4, R0);       /* R0 <- MappedMemoryWriteWord */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitJSR(b, R0);                 /* Call MappedMemoryWriteWord */
    emitALU(b, R1, R4, OP_ADD);     /* R4 <- R4 + R1 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVLS0(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R8, regm, R5);    /* R5 <- sh2[Rm] */
    emitMOVLL4(b, R8, 0, R1);       /* R1 <- sh2[R0] */
    emitMOVLL4(b, R9, 5, R0);       /* R0 <- MappedMemoryWriteLong */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitJSR(b, R0);                 /* Call MappedMemoryWriteLong */
    emitALU(b, R1, R4, OP_ADD);     /* R4 <- R4 + R1 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVBL0(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R9, 0, R0);       /* R0 <- MappedMemoryReadByte */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVLL4(b, R8, 0, R1);       /* R1 <- sh2[R0] */
    emitJSR(b, R0);                 /* Call MappedMemoryReadByte */
    emitALU(b, R1, R4, OP_ADD);     /* R4 <- R4 + R1 */
    emitALU(b, R0, R0, OP_EXTSB);   /* Sign extend read byte */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- read byte */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVWL0(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R9, 1, R0);       /* R0 <- MappedMemoryReadWord */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVLL4(b, R8, 0, R1);       /* R1 <- sh2[R0] */
    emitJSR(b, R0);                 /* Call MappedMemoryReadWord */
    emitALU(b, R1, R4, OP_ADD);     /* R4 <- R4 + R1 */
    emitALU(b, R0, R0, OP_EXTSW);   /* Sign extend read word */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- read word */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVLL0(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R9, 2, R0);       /* R0 <- MappedMemoryReadLong */
    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVLL4(b, R8, 0, R1);       /* R1 <- sh2[R0] */
    emitJSR(b, R0);                 /* Call MappedMemoryReadLong */
    emitALU(b, R1, R4, OP_ADD);     /* R4 <- R4 + R1 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- read long */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVI(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int imm = INSTRUCTION_CD(inst);

    emitMOVI(b, imm, R2);           /* R2 <- #imm */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVWI(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int imm = INSTRUCTION_CD(inst);
    uint32_t addr = b->pc + 4 + (imm << 1);

    if(((uint32_t)b->ptr) & 0x03) {
        emitMOVLI(b, 1, R4);        /* R4 <- calculated effective addr */
        emitBRA(b, 2);              /* Jump beyond the constant */
        emitMOVLL4(b, R9, 1, R0);   /* R0 <- MappedMemoryReadWord */
        emit32(b, addr);            /* MOV.W effective address */
    }
    else {
        emitMOVLI(b, 1, R4);        /* R4 <- calculated effective addr */
        emitBRA(b, 3);              /* Jump beyond the constant */
        emitMOVLL4(b, R9, 1, R0);   /* R0 <- MappedMemoryReadWord */
        emit16(b, 0);               /* Padding, for alignment issues */
        emit32(b, addr);            /* MOV.W effective address */
    }

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R0);                 /* Call MappedMemoryReadWord */
    emitNOP(b);                     /* XXXX: Nothing to put here */
    emitALU(b, R0, R0, OP_EXTSW);   /* Sign extend read word */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- read word */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVLI(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int imm = INSTRUCTION_CD(inst);
    uint32_t addr = ((b->pc + 4) & 0xFFFFFFFC) + (imm << 2);

    if(((uint32_t)b->ptr) & 0x03) {
        emitMOVLI(b, 1, R4);        /* R4 <- calculated effective addr */
        emitBRA(b, 2);              /* Jump beyond the constant */
        emitMOVLL4(b, R9, 2, R0);   /* R0 <- MappedMemoryReadLong */
        emit32(b, addr);            /* MOV.L effective address */
    }
    else {
        emitMOVLI(b, 1, R4);        /* R4 <- calculated effective addr */
        emitBRA(b, 3);              /* Jump beyond the constant */
        emitMOVLL4(b, R9, 2, R0);   /* R0 <- MappedMemoryReadLong */
        emit16(b, 0);               /* Padding, for alignment issues */
        emit32(b, addr);            /* MOV.L effective address */
    }

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R0);                 /* Call MappedMemoryReadLong */
    emitNOP(b);                     /* XXXX: Nothing to put here */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- read long */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVBLG(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R9, 0, R1);       /* R1 <- MappedMemoryReadByte */
    emitMOVI(b, imm, R4);           /* R4 <- Displacement */
    emitMOVLLG(b, 17);              /* R0 <- sh2[GBR] */
    emitALU(b, R4, R4, OP_EXTUB);   /* Zero extend displacement */
    emitJSR(b, R1);                 /* Call MappedMemoryReadByte */
    emitALU(b, R0, R4, OP_ADD);     /* R4 <- R4 + R0 */
    emitALU(b, R0, R0, OP_EXTSB);   /* Sign extend read byte */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, 0, R8);       /* sh2[R0] <- read byte */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVWLG(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVI(b, imm, R4);           /* R4 <- Displacement */
    emitMOVLL4(b, R9, 1, R1);       /* R1 <- MappedMemoryReadWord */
    emitALU(b, R4, R4, OP_EXTUB);   /* Zero extend displacement */
    emitMOVLLG(b, 17);              /* R0 <- sh2[GBR] */
    emitSHIFT(b, R4, OP_SHLL);      /* Double displacement */
    emitJSR(b, R1);                 /* Call MappedMemoryReadWord */
    emitALU(b, R0, R4, OP_ADD);     /* R4 <- R4 + R0 */
    emitALU(b, R0, R0, OP_EXTSW);   /* Sign extend read word */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, 0, R8);       /* sh2[R0] <- read word */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVLLG(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVI(b, imm, R4);           /* R4 <- Displacement */
    emitMOVLL4(b, R9, 2, R1);       /* R1 <- MappedMemoryReadLong */
    emitALU(b, R4, R4, OP_EXTUB);   /* Zero extend displacement */
    emitMOVLLG(b, 17);              /* R0 <- sh2[GBR] */
    emitSHLL2(b, R4);               /* Quadruple displacement */
    emitJSR(b, R1);                 /* Call MappedMemoryReadLong */
    emitALU(b, R0, R4, OP_ADD);     /* R4 <- R4 + R0 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, 0, R8);       /* sh2[R0] <- read long */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVBSG(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);

    emitMOVLL4(b, R8, 0, R5);       /* R5 <- sh2[R0] */
    emitMOVLLG(b, 17);              /* R0 <- sh2[GBR] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R9, 3, R1);       /* R1 <- MappedMemoryWriteByte */
    emitMOVI(b, imm, R4);           /* R4 <- Displacement */
    emitALU(b, R4, R4, OP_EXTUB);   /* Zero extend Displacement */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteByte */
    emitALU(b, R0, R4, OP_ADD);     /* R4 <- R4 + R0 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVWSG(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);

    emitMOVLL4(b, R8, 0, R5);       /* R5 <- sh2[R0] */
    emitMOVI(b, imm, R4);           /* R4 <- Displacement */
    emitMOVLLG(b, 17);              /* R0 <- sh2[GBR] */
    emitALU(b, R4, R4, OP_EXTUB);   /* Zero extend Displacement */
    emitMOVLL4(b, R9, 4, R1);       /* R1 <- MappedMemoryWriteWord */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitSHIFT(b, R4, OP_SHLL);      /* Double displacement */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteWord */
    emitALU(b, R0, R4, OP_ADD);     /* R4 <- R4 + R0 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVLSG(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);

    emitMOVLL4(b, R8, 0, R5);       /* R5 <- sh2[R0] */
    emitMOVI(b, imm, R4);           /* R4 <- Displacement */
    emitMOVLLG(b, 17);              /* R0 <- sh2[GBR] */
    emitALU(b, R4, R4, OP_EXTUB);   /* Zero extend Displacement */
    emitMOVLL4(b, R9, 5, R1);       /* R1 <- MappedMemoryWriteLong */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitSHLL2(b, R4);               /* Quadruple displacement */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteLong */
    emitALU(b, R0, R4, OP_ADD);     /* R4 <- R4 + R0 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVBS4(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_C(inst);
    int imm = INSTRUCTION_D(inst);

    emitMOVLL4(b, R8, 0, R5);       /* R5 <- sh2[R0] */
    emitMOVLL4(b, R9, 3, R1);       /* R1 <- MappedMemoryWriteByte */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteByte */
    emitADDI(b, imm, R4);           /* R4 <- R4 + displacement */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVWS4(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_C(inst);
    int imm = INSTRUCTION_D(inst) << 1;

    emitMOVLL4(b, R8, 0, R5);       /* R5 <- sh2[R0] */
    emitMOVLL4(b, R9, 4, R1);       /* R1 <- MappedMemoryWriteWord */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteWord */
    emitADDI(b, imm, R4);           /* R4 <- R4 + displacement */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVLS4(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);
    int imm = INSTRUCTION_D(inst) << 2;

    emitMOVLL4(b, R8, regm, R5);    /* R5 <- sh2[Rm] */
    emitMOVLL4(b, R9, 5, R1);       /* R1 <- MappedMemoryWriteLong */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteLong */
    emitADDI(b, imm, R4);           /* R4 <- R4 + displacement */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVBL4(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_C(inst);
    int imm = INSTRUCTION_D(inst);

    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVLL4(b, R9, 0, R1);       /* R1 <- MappedMemoryReadByte */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R1);                 /* Call MappedMemoryReadByte */
    emitADDI(b, imm, R4);           /* R4 <- R4 + displacement */
    emitALU(b, R0, R0, OP_EXTSB);   /* Sign extend read byte */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, 0, R8);       /* sh2[R0] <- read byte */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVWL4(uint16_t inst, sh2rec_block_t *b) {
    int regm = INSTRUCTION_C(inst);
    int imm = INSTRUCTION_D(inst) << 1;

    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVLL4(b, R9, 1, R1);       /* R1 <- MappedMemoryReadWord */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R1);                 /* Call MappedMemoryReadWord */
    emitADDI(b, imm, R4);           /* R4 <- R4 + displacement */
    emitALU(b, R0, R0, OP_EXTSW);   /* Sign extend read word */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, 0, R8);       /* sh2[R0] <- read word */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVLL4(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);
    int imm = INSTRUCTION_D(inst) << 2;

    emitMOVLL4(b, R8, regm, R4);    /* R4 <- sh2[Rm] */
    emitMOVLL4(b, R9, 2, R1);       /* R1 <- MappedMemoryReadLong */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R1);                 /* Call MappedMemoryReadLong */
    emitADDI(b, imm, R4);           /* R4 <- R4 + displacement */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- read long */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVA(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);
    uint32_t addr = ((b->pc + 4) & 0xFFFFFFFC) + (imm << 2);

    if(((uint32_t)b->ptr) & 0x03) {
        emitMOVLI(b, 1, R2);        /* R2 <- calculated effective addr */
        emitBRA(b, 2);              /* Jump beyond the constant */
        emitMOVLS4(b, R2, 0, R8);   /* sh2[R0] <- R2 */
        emit32(b, addr);            /* MOVA effective address */
    }
    else {
        emitMOVLI(b, 1, R2);        /* R2 <- calculated effective addr */
        emitBRA(b, 3);              /* Jump beyond the constant */
        emitMOVLS4(b, R2, 0, R8);   /* sh2[R0] <- R2 */
        emit16(b, 0);               /* Padding, for alignment issues */
        emit32(b, addr);            /* MOVA effective address */
    }

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMOVT(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitANDI(b, 0x01);              /* Grab T Bit */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- T Bit */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMULL(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitMOVLL4(b, R8, regm, R3);    /* R3 <- sh2[Rm] */
    emitALU(b, R3, R2, OP_MULL);    /* MACL <- R2 * R3 */

    b->cycles += 2;                 /* 2 Cycles */
    b->pc += 2;
}

static void generateMULS(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitMOVLL4(b, R8, regm, R3);    /* R3 <- sh2[Rm] */
    emitALU(b, R3, R2, OP_MULS);    /* MACL <- (s16)R2 * (s16)R3 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateMULU(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitMOVLL4(b, R8, regm, R3);    /* R3 <- sh2[Rm] */
    emitALU(b, R3, R2, OP_MULU);    /* MACL <- (u16)R2 * (u16)R3 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateNEG(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLL4(b, R8, regm, R3);    /* R3 <- sh2[Rm] */
    emitALU(b, R3, R2, OP_NEG);     /* R2 <- 0 - R3 */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateNEGC(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);
    
    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLL4(b, R8, regm, R3);    /* R3 <- sh2[Rm] */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitALU(b, R3, R2, OP_NEGC);    /* R2 = 0 - R3 - T (borrow to T) */
    emitSHIFT(b, R0, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateNOP(uint16_t inst, sh2rec_block_t *b) {
    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateNOT(uint16_t inst, sh2rec_block_t *b) {
    generateALUOP(inst, b, OP_NOT);
    b->pc += 2;
}

static void generateOR(uint16_t inst, sh2rec_block_t *b) {
    generateALUOP(inst, b, OP_OR);
    b->pc += 2;
}

static void generateORI(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);

    emitMOVLL4(b, R8, 0, R0);       /* R0 <- sh2[R0] */
    emitORI(b, imm);                /* R0 <- R0 | #imm */
    emitMOVLS4(b, R0, 0, R8);       /* sh2[R0] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateORM(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLLG(b, 17);              /* R0 <- sh2[GBR] */
    emitMOVLL4(b, R8, 0, R4);       /* R4 <- sh2[R0] */
    emitMOVLL4(b, R9, 0, R1);       /* R1 <- MappedMemoryReadByte */
    emitALU(b, R0, R4, OP_ADD);     /* R4 <- R4 + R0 */
    emitJSR(b, R1);                 /* Call MappedMemoryReadByte */
    emitMOVLM(b, R4, R15);          /* Push R4 on the stack (delay slot) */
    emitMOVLL4(b, R9, 3, R1);       /* R1 <- MappedMemoryWriteByte */
    emitORI(b, imm);                /* R0 <- R0 | #imm */
    emitMOVLP(b, R15, R4);          /* Pop R4 off the stack */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteByte */
    emitMOV(b, R0, R5);             /* R5 <- R0 (delay slot) */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    b->cycles += 3;                 /* 3 Cycles */
    b->pc += 2;
}

static void generateROTCL(uint16_t inst, sh2rec_block_t *b) {
    generateSHIFT(inst, b, OP_ROTCL);
    b->pc += 2;
}

static void generateROTCR(uint16_t inst, sh2rec_block_t *b) {
    generateSHIFT(inst, b, OP_ROTCR);
    b->pc += 2;
}

static void generateROTL(uint16_t inst, sh2rec_block_t *b) {
    generateSHIFT(inst, b, OP_ROTL);
    b->pc += 2;
}

static void generateROTR(uint16_t inst, sh2rec_block_t *b) {
    generateSHIFT(inst, b, OP_ROTR);
    b->pc += 2;
}

static void generateRTE(uint16_t inst, sh2rec_block_t *b) {
    emitMOVLL4(b, R9, 2, R0);       /* R0 <- MappedMemoryReadLong */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R0);                 /* Call MappedMemoryReadLong */
    emitMOVLL4(b, R8, 15, R4);      /* R4 <- sh2[R15] (delay slot) */
    emitMOVLL4(b, R9, 2, R1);       /* R1 <- MappedMemoryReadLong */
    emitMOVLL4(b, R8, 15, R4);      /* R4 <- sh2[R15] */
    emitMOVI(b, 4, R2);             /* R2 <- 4 */
    emitALU(b, R2, R4, OP_ADD);     /* R4 <- R4 + R2 */
    emitMOVLM(b, R0, R15);          /* Push the next PC */
    emitALU(b, R4, R2, OP_ADD);     /* R2 <- R4 + R2 */
    emitJSR(b, R1);                 /* Call MappedMemoryReadLong */
    emitMOVLS4(b, R2, 15, R8);      /* sh2[R15] <- R2 (delay slot) */
    emitMOVWI(b, 1, R1);            /* R1 <- 0x000003F3 */
    emitBRA(b, 1);                  /* Branch around the constant */
    emitALU(b, R1, R0, OP_AND);     /* R0 <- R0 & R1 */
    emit16(b, 0x03F3);              /* Mask for SR register */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    /* Deal with the delay slot */
    b->pc += 2;
    sh2rec_rec_inst(b, 1);

    emitRTS(b);                     /* Return to sender! */
    emitMOVLP(b, R15, R0);          /* Pop the next PC (delay slot) */

    b->cycles += 4;                 /* 4 Cycles */
}    

static void generateRTS(uint16_t inst, sh2rec_block_t *b) {
    emitMOVLLG(b, 21);              /* R0 <- sh2[PR] */
    emitMOVLM(b, R0, R15);          /* Push the PR on the stack */

    /* Deal with the delay slot */
    b->pc += 2;
    sh2rec_rec_inst(b, 1);

    emitRTS(b);                     /* Return to sender! */
    emitMOVLP(b, R15, R0);          /* Pop the next PC (delay slot) */

    b->cycles += 2;                 /* 2 Cycles */
}

static void generateSETT(uint16_t inst, sh2rec_block_t *b) {
    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitORI(b, 0x01);               /* Set T Bit */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSHAL(uint16_t inst, sh2rec_block_t *b) {
    generateSHIFT(inst, b, OP_SHAL);
    b->pc += 2;
}

static void generateSHAR(uint16_t inst, sh2rec_block_t *b) {
    generateSHIFT(inst, b, OP_SHAR);
    b->pc += 2;
}

static void generateSHLL(uint16_t inst, sh2rec_block_t *b) {
    generateSHIFT(inst, b, OP_SHLL);
    b->pc += 2;
}

static void generateSHLL2(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitSHLL2(b, R2);               /* R2 <- R2 << 2 */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSHLL8(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitSHLL8(b, R2);               /* R2 <- R2 << 8 */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSHLL16(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitSHLL16(b, R2);              /* R2 <- R2 << 16 */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSHLR(uint16_t inst, sh2rec_block_t *b) {
    generateSHIFT(inst, b, OP_SHLR);
    b->pc += 2;
}

static void generateSHLR2(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitSHLR2(b, R2);               /* R2 <- R2 >> 2 */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSHLR8(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitSHLR8(b, R2);               /* R2 <- R2 >> 8 */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSHLR16(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitSHLR16(b, R2);              /* R2 <- R2 >> 16 */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSLEEP(uint16_t inst, sh2rec_block_t *b) {
    b->cycles += 3;                 /* 3 Cycles */
    b->pc += 2;
}

static void generateSTCSR(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSTCGBR(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLLG(b, 17);              /* R0 <- sh2[GBR] */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSTCVBR(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLLG(b, 18);              /* R0 <- sh2[VBR] */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSTCMSR(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLL4(b, R9, 5, R1);       /* R1 <- MappedMemoryWriteLong */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitADDI(b, -4, R4);            /* R4 -= 4 */
    emitMOV(b, R0, R5);             /* R5 <- R0 */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteLong */
    emitMOVLS4(b, R4, regn, R8);    /* sh2[Rn] <- R4 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    b->cycles += 2;                 /* 2 Cycles */
    b->pc += 2;
}

static void generateSTCMGBR(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLLG(b, 17);              /* R0 <- sh2[GBR] */
    emitMOVLL4(b, R9, 5, R1);       /* R1 <- MappedMemoryWriteLong */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitADDI(b, -4, R4);            /* R4 -= 4 */
    emitMOV(b, R0, R5);             /* R5 <- R0 */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteLong */
    emitMOVLS4(b, R4, regn, R8);    /* sh2[Rn] <- R4 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    b->cycles += 2;                 /* 2 Cycles */
    b->pc += 2;
}

static void generateSTCMVBR(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLLG(b, 18);              /* R0 <- sh2[VBR] */
    emitMOVLL4(b, R9, 5, R1);       /* R1 <- MappedMemoryWriteLong */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitADDI(b, -4, R4);            /* R4 -= 4 */
    emitMOV(b, R0, R5);             /* R5 <- R0 */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteLong */
    emitMOVLS4(b, R4, regn, R8);    /* sh2[Rn] <- R4 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    b->cycles += 2;                 /* 2 Cycles */
    b->pc += 2;
}

static void generateSTSMACH(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitSTS(b, R_MACH, R0);         /* R0 <- MACH */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSTSMACL(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitSTS(b, R_MACL, R0);         /* R0 <- MACL */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSTSPR(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLLG(b, 21);              /* R0 <- sh2[PR] */
    emitMOVLS4(b, R0, regn, R8);    /* sh2[Rn] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSTSMMACH(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitSTS(b, R_MACH, R5);         /* R5 <- MACH */
    emitMOVLL4(b, R9, 5, R1);       /* R1 <- MappedMemoryWriteLong */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitADDI(b, -4, R4);            /* R4 -= 4 */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteLong */
    emitMOVLS4(b, R4, regn, R8);    /* sh2[Rn] <- R4 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSTSMMACL(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitSTS(b, R_MACL, R5);         /* R5 <- MACL */
    emitMOVLL4(b, R9, 5, R1);       /* R1 <- MappedMemoryWriteLong */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitADDI(b, -4, R4);            /* R4 -= 4 */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteLong */
    emitMOVLS4(b, R4, regn, R8);    /* sh2[Rn] <- R4 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSTSMPR(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLLG(b, 21);              /* R0 <- sh2[PR] */
    emitMOVLL4(b, R9, 5, R1);       /* R1 <- MappedMemoryWriteLong */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitADDI(b, -4, R4);            /* R4 -= 4 */
    emitMOV(b, R0, R5);             /* R5 <- R0 */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteLong */
    emitMOVLS4(b, R4, regn, R8);    /* sh2[Rn] <- R4 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSUB(uint16_t inst, sh2rec_block_t *b) {
    generateALUOP(inst, b, OP_SUB);
    b->pc += 2;
}

static void generateSUBC(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitMOVLL4(b, R8, regm, R3);    /* R3 <- sh2[Rm] */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitALU(b, R3, R2, OP_SUBC);    /* R2 = R2 - R3 - T (borrow to T) */
    emitSHIFT(b, R0, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitMOVLS4(b, R2, regn, R8);    /* sh2[Rn] <- R2 */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSUBV(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);
    int regm = INSTRUCTION_C(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVLL4(b, R8, regn, R2);    /* R2 <- sh2[Rn] */
    emitMOVLL4(b, R8, regm, R3);    /* R3 <- sh2[Rm] */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitSUBV(b, R3, R2);            /* R2 = R2 - R3 (underflow to T Bit) */
    emitSHIFT(b, R0, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateSWAPB(uint16_t inst, sh2rec_block_t *b) {
    generateALUOP(inst, b, OP_SWAPB);
    b->pc += 2;
}

static void generateSWAPW(uint16_t inst, sh2rec_block_t *b) {
    generateALUOP(inst, b, OP_SWAPW);
    b->pc += 2;
}

static void generateTAS(uint16_t inst, sh2rec_block_t *b) {
    int regn = INSTRUCTION_B(inst);

    emitMOVLL4(b, R9, 0, R0);       /* R0 <- MappedMemoryReadByte */
    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitJSR(b, R0);                 /* Call MappedMemoryReadByte */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] (delay slot) */
    emitMOV(b, R0, R5);             /* R5 <- R0 (byte read) */
    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOVI(b, 0x80, R2);          /* R2 <- 0x80 */
    emitMOVLL4(b, R8, regn, R4);    /* R4 <- sh2[Rn] */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitALU(b, R5, R5, OP_TST);     /* T <- 1 if byte == 0, 0 otherwise */
    emitSHIFT(b, R0, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitMOVLL4(b, R9, 3, R1);       /* R1 <- MappedMemoryWriteByte */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteByte */
    emitALU(b, R2, R5, OP_OR);      /* R5 <- R5 | 0x80 (delay slot) */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    b->cycles += 4;                 /* 4 Cycles */
    b->pc += 2;
}

static void generateTRAPA(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);
    int disp = (((uint32_t)(b->ptr)) & 0x03) ? 5 : 6;
    uint32_t val = b->pc + 2;

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R8, 15, R4);      /* R4 <- sh2[R15] */
    emitMOVLL4(b, R9, 5, R1);       /* R1 <- MemoryMappedWriteLong */
    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitADDI(b, -4, R4);            /* R4 <- R4 - 4 */
    emitJSR(b, R1);                 /* Call MemoryMappedWriteLong */
    emitMOV(b, R0, R5);             /* R5 <- R0 (delay slot) */
    emitMOVLL4(b, R8, 15, R4);      /* R4 <- sh2[R15] */
    emitMOVLL4(b, R9, 5, R1);       /* R1 <- MemoryMappedWriteLong */
    emitADDI(b, -8, R4);            /* R4 <- R4 - 8 */
    emitMOVLI(b, disp, R5);         /* R5 <- Updated PC value (to be stacked) */
    emitJSR(b, R1);                 /* Call MemoryMappedWriteLong */
    emitMOVLS4(b, R4, 15, R8);      /* sh2[R15] <- R4 (delay slot) */
    emitMOVI(b, imm, R4);           /* R4 <- immediate data */
    emitALU(b, R4, R4, OP_EXTUB);   /* Zero-extend R4 */
    emitMOVLL4(b, R9, 2, R1);       /* R1 <- MemoryMappedReadLong */
    emitMOVLLG(b, 18);              /* R0 <- sh2[VBR] */
    emitSHLL2(b, R4);               /* R4 <- R4 << 2 */
    emitJSR(b, R1);                 /* Call MemoryMappedReadLong */
    emitALU(b, R0, R4, OP_ADD);     /* R4 <- R4 + R0 (delay slot) */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */
    emitRTS(b);                     /* Return to sender! */
    emitNOP(b);                     /* XXXX: Nothing here */
    if(((uint32_t)b->ptr) & 0x03)
        emit16(b, 0);               /* Padding for the alignment */
    emit32(b, val);                 /* The PC value to be loaded by the MOVLI */
    
    b->cycles += 8;                 /* 8 Cycles */
}

static void generateTST(uint16_t inst, sh2rec_block_t *b) {
    generateCOMP(inst, b, OP_TST);
    b->pc += 2;
}

static void generateTSTI(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);

    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitMOV(b, R0, R2);             /* R2 <- R0 */
    emitMOVLL4(b, R8, 0, R0);       /* R0 <- sh2[R0] */
    emitSHIFT(b, R2, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitTSTI(b, imm);               /* tst #imm, r0 */
    emitSHIFT(b, R2, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitMOV(b, R2, R0);             /* R0 <- R2 */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateTSTM(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLL4(b, R9, 0, R1);       /* R1 <- MappedMemoryReadByte */
    emitMOVLLG(b, 17);              /* R0 <- sh2[GBR] */
    emitMOVLL4(b, R8, 0, R4);       /* R4 <- sh2[R0] */
    emitJSR(b, R1);                 /* Call MappedMemoryReadByte */
    emitALU(b, R0, R4, OP_ADD);     /* R4 <- R4 + R0 (delay slot) */
    emitMOV(b, R0, R5);             /* R5 <- R0 (byte read) */
    emitMOVI(b, imm, R3);           /* R3 <- immediate value */
    emitMOVLLG(b, 16);              /* R0 <- sh2[SR] */
    emitSHIFT(b, R0, OP_ROTCR);     /* Rotate SH2's T Bit in place */
    emitALU(b, R3, R5, OP_TST);     /* T <- 1 if (R5 & imm) == 0, 0 otherwise */
    emitSHIFT(b, R0, OP_ROTCL);     /* Rotate T back to SH2 reg */
    emitMOVLSG(b, 16);              /* sh2[SR] <- R0 */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    b->cycles += 3;                 /* 3 Cycles */
    b->pc += 2;
}

static void generateXOR(uint16_t inst, sh2rec_block_t *b) {
    generateALUOP(inst, b, OP_XOR);
    b->pc += 2;
}

static void generateXORI(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);

    emitMOVLL4(b, R8, 0, R0);       /* R0 <- sh2[R0] */
    emitXORI(b, imm);               /* R0 <- R0 ^ #imm */
    emitMOVLS4(b, R0, 0, R8);       /* sh2[R0] <- R0 */

    ++b->cycles;                    /* 1 Cycle */
    b->pc += 2;
}

static void generateXORM(uint16_t inst, sh2rec_block_t *b) {
    int imm = INSTRUCTION_CD(inst);

    emitSTS(b, R_PR, R10);          /* R10 <- PR */
    emitMOVLLG(b, 17);              /* R0 <- sh2[GBR] */
    emitMOVLL4(b, R8, 0, R4);       /* R4 <- sh2[R0] */
    emitMOVLL4(b, R9, 0, R1);       /* R1 <- MappedMemoryReadByte */
    emitALU(b, R0, R4, OP_ADD);     /* R4 <- R4 + R0 */
    emitJSR(b, R1);                 /* Call MappedMemoryReadByte */
    emitMOVLM(b, R4, R15);          /* Push R4 on the stack (delay slot) */
    emitMOVLL4(b, R9, 3, R1);       /* R1 <- MappedMemoryWriteByte */
    emitXORI(b, imm);               /* R0 <- R0 ^ #imm */
    emitMOVLP(b, R15, R4);          /* Pop R4 off the stack */
    emitJSR(b, R1);                 /* Call MappedMemoryWriteByte */
    emitMOV(b, R0, R5);             /* R5 <- R0 (delay slot) */
    emitLDS(b, R10, R_PR);          /* PR <- R10 */

    b->cycles += 3;                 /* 3 Cycles */
    b->pc += 2;
}

static void generateXTRCT(uint16_t inst, sh2rec_block_t *b) {
    generateALUOP(inst, b, OP_XTRCT);
    b->pc += 2;
}

int sh2rec_rec_inst(sh2rec_block_t *b, int isdelay) {
    uint16_t inst = MappedMemoryReadWord(b->pc);
    int done = 0;

    switch(INSTRUCTION_A(inst)) {
        case 0:
            switch(INSTRUCTION_D(inst)) {
                case 2:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateSTCSR(inst, b);    break;
                        case 1:  generateSTCGBR(inst, b);   break;
                        case 2:  generateSTCVBR(inst, b);   break;
                        default: return -1;
                    }
                    break;

                case 3:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateBSRF(inst, b); done = 1;   break;
                        case 2:  generateBRAF(inst, b); done = 1;   break;
                        default: return -1;
                    }
                    break;

                case 4:  generateMOVBS0(inst, b);   break;
                case 5:  generateMOVWS0(inst, b);   break;
                case 6:  generateMOVLS0(inst, b);   break;
                case 7:  generateMULL(inst, b);     break;
                case 8:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateCLRT(inst, b);     break;
                        case 1:  generateSETT(inst, b);     break;
                        case 2:  generateCLRMAC(inst, b);   break;
                        default: return -1;
                    }
                    break;

                case 9:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateNOP(inst, b);      break;
                        case 1:  generateDIV0U(inst, b);    break;
                        case 2:  generateMOVT(inst, b);     break;
                        default: return -1;
                    }
                    break;

                case 10:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateSTSMACH(inst, b);  break;
                        case 1:  generateSTSMACL(inst, b);  break;
                        case 2:  generateSTSPR(inst, b);    break;
                        default: return -1;
                    }
                    break;

                case 11:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateRTS(inst, b);      done = 1;   break;
                        case 1:  generateSLEEP(inst, b);    break;
                        case 2:  generateRTE(inst, b);      done = 1;   break;
                        default: return -1;
                    }
                    break;

                case 12: generateMOVBL0(inst, b);   break;
                case 13: generateMOVWL0(inst, b);   break;
                case 14: generateMOVLL0(inst, b);   break;
                case 15: generateMACL(inst, b);     break;
                default: return -1;
            }
            break;

        case 1:  generateMOVLS4(inst, b);   break;
        case 2:
            switch(INSTRUCTION_D(inst)) {
                case 0:  generateMOVBS(inst, b);    break;
                case 1:  generateMOVWS(inst, b);    break;
                case 2:  generateMOVLS(inst, b);    break;
                case 4:  generateMOVBM(inst, b);    break;
                case 5:  generateMOVWM(inst, b);    break;
                case 6:  generateMOVLM(inst, b);    break;
                case 7:  generateDIV0S(inst, b);    break;
                case 8:  generateTST(inst, b);      break;
                case 9:  generateAND(inst, b);      break;
                case 10: generateXOR(inst, b);      break;
                case 11: generateOR(inst, b);       break;
                case 12: generateCMPSTR(inst, b);   break;
                case 13: generateXTRCT(inst, b);    break;
                case 14: generateMULU(inst, b);     break;
                case 15: generateMULS(inst, b);     break;
                default: return -1;
            }
            break;

        case 3:
            switch(INSTRUCTION_D(inst)) {
                case 0:  generateCMPEQ(inst, b);    break;
                case 2:  generateCMPHS(inst, b);    break;
                case 3:  generateCMPGE(inst, b);    break;
                case 4:  generateDIV1(inst, b);     break;
                case 5:  generateDMULU(inst, b);    break;
                case 6:  generateCMPHI(inst, b);    break;
                case 7:  generateCMPGT(inst, b);    break;
                case 8:  generateSUB(inst, b);      break;
                case 10: generateSUBC(inst, b);     break;
                case 11: generateSUBV(inst, b);     break;
                case 12: generateADD(inst, b);      break;
                case 13: generateDMULS(inst, b);    break;
                case 14: generateADDC(inst, b);     break;
                case 15: generateADDV(inst, b);     break;
                default: return -1;
            }
            break;

        case 4:
            switch(INSTRUCTION_D(inst)) {
                case 0:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateSHLL(inst, b);     break;
                        case 1:  generateDT(inst, b);       break;
                        case 2:  generateSHAL(inst, b);     break;
                        default: return -1;
                    }
                    break;

                case 1:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateSHLR(inst, b);     break;
                        case 1:  generateCMPPZ(inst, b);    break;
                        case 2:  generateSHAR(inst, b);     break;
                        default: return -1;
                    }
                    break;

                case 2:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateSTSMMACH(inst, b); break;
                        case 1:  generateSTSMMACL(inst, b); break;
                        case 2:  generateSTSMPR(inst, b);   break;
                        default: return -1;
                    }
                    break;

                case 3:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateSTCMSR(inst, b);   break;
                        case 1:  generateSTCMGBR(inst, b);  break;
                        case 2:  generateSTCMVBR(inst, b);  break;
                        default: return -1;
                    }
                    break;

                case 4:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateROTL(inst, b);     break;
                        case 2:  generateROTCL(inst, b);    break;
                        default: return -1;
                    }
                    break;

                case 5:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateROTR(inst, b);     break;
                        case 1:  generateCMPPL(inst, b);    break;
                        case 2:  generateROTCR(inst, b);    break;
                        default: return -1;
                    }
                    break;

                case 6:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateLDSMMACH(inst, b); break;
                        case 1:  generateLDSMMACL(inst, b); break;
                        case 2:  generateLDSMPR(inst, b);   break;
                        default: return -1;
                    }
                    break;

                case 7:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateLDCMSR(inst, b);   break;
                        case 1:  generateLDCMGBR(inst, b);  break;
                        case 2:  generateLDCMVBR(inst, b);  break;
                        default: return -1;
                    }
                    break;

                case 8:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateSHLL2(inst, b);    break;
                        case 1:  generateSHLL8(inst, b);    break;
                        case 2:  generateSHLL16(inst, b);   break;
                        default: return -1;
                    }
                    break;

                case 9:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateSHLR2(inst, b);    break;
                        case 1:  generateSHLR8(inst, b);    break;
                        case 2:  generateSHLR16(inst, b);   break;
                        default: return -1;
                    }
                    break;

                case 10:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateLDSMACH(inst, b);  break;
                        case 1:  generateLDSMACL(inst, b);  break;
                        case 2:  generateLDSPR(inst, b);    break;
                        default: return -1;
                    }
                    break;

                case 11:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateJSR(inst, b);      done = 1;   break;
                        case 1:  generateTAS(inst, b);      break;
                        case 2:  generateJMP(inst, b);      done = 1;   break;
                        default: return -1;
                    }
                    break;

                case 14:
                    switch(INSTRUCTION_C(inst)) {
                        case 0:  generateLDCSR(inst, b);    break;
                        case 1:  generateLDCGBR(inst, b);   break;
                        case 2:  generateLDCVBR(inst, b);   break;
                        default: return -1;
                    }
                    break;

                case 15: generateMACW(inst, b);     break;
                default: return -1;
            }
            break;

        case 5:  generateMOVLL4(inst, b);   break;

        case 6:
            switch(INSTRUCTION_D(inst)) {
                case 0:  generateMOVBL(inst, b);    break;
                case 1:  generateMOVWL(inst, b);    break;
                case 2:  generateMOVLL(inst, b);    break;
                case 3:  generateMOV(inst, b);      break;
                case 4:  generateMOVBP(inst, b);    break;
                case 5:  generateMOVWP(inst, b);    break;
                case 6:  generateMOVLP(inst, b);    break;
                case 7:  generateNOT(inst, b);      break;
                case 8:  generateSWAPB(inst, b);    break;
                case 9:  generateSWAPW(inst, b);    break;
                case 10: generateNEGC(inst, b);     break;
                case 11: generateNEG(inst, b);      break;
                case 12: generateEXTUB(inst, b);    break;
                case 13: generateEXTUW(inst, b);    break;
                case 14: generateEXTSB(inst, b);    break;
                case 15: generateEXTSW(inst, b);    break;
            }
            break;

        case 7:  generateADDI(inst, b);     break;

        case 8:
            switch(INSTRUCTION_B(inst)) {
                case 0:  generateMOVBS4(inst, b);   break;
                case 1:  generateMOVWS4(inst, b);   break;
                case 4:  generateMOVBL4(inst, b);   break;
                case 5:  generateMOVWL4(inst, b);   break;
                case 8:  generateCMPIM(inst, b);    break;
                case 9:  generateBT(inst, b);       done = 1;   break;
                case 11: generateBF(inst, b);       done = 1;   break;
                case 13: generateBTS(inst, b);      done = 1;   break;
                case 15: generateBFS(inst, b);      done = 1;   break;
                default: return -1;
            }
            break;

        case 9:  generateMOVWI(inst, b);    break;
        case 10: generateBRA(inst, b);      done = 1;   break;
        case 11: generateBSR(inst, b);      done = 1;   break;

        case 12:
            switch(INSTRUCTION_B(inst)) {
                case 0:  generateMOVBSG(inst, b);   break;
                case 1:  generateMOVWSG(inst, b);   break;
                case 2:  generateMOVLSG(inst, b);   break;
                case 3:  generateTRAPA(inst, b);    done = 1;   break;
                case 4:  generateMOVBLG(inst, b);   break;
                case 5:  generateMOVWLG(inst, b);   break;
                case 6:  generateMOVLLG(inst, b);   break;
                case 7:  generateMOVA(inst, b);     break;
                case 8:  generateTSTI(inst, b);     break;
                case 9:  generateANDI(inst, b);     break;
                case 10: generateXORI(inst, b);     break;
                case 11: generateORI(inst, b);      break;
                case 12: generateTSTM(inst, b);     break;
                case 13: generateANDM(inst, b);     break;
                case 14: generateXORM(inst, b);     break;
                case 15: generateORM(inst, b);      break;
            }
            break;

        case 13: generateMOVLI(inst, b);    break;
        case 14: generateMOVI(inst, b);     break;
        default: return -1;
    }

    return done;
}

int sh2rec_rec_block(sh2rec_block_t *b) {
    int done = 0;

    while(!done) {
        done = sh2rec_rec_inst(b, 0);
    }

    /* Flush the icache, so we don't execute stale data */
    icache_flush_range((uint32)b->block, ((u32)b->ptr) - ((u32)b->block));

    return 0;
}

/* In sh2exec.s */
extern void sh2rec_exec(SH2_struct *cxt, u32 cycles);

static int sh2rec_init(void) {
    /* Initialize anything important here */
    sh2rec_htab_init();
    return 0;
}

static void sh2rec_deinit(void) {
    /* Clean stuff up here */
    sh2rec_htab_reset();
}

static void sh2rec_reset(void) {
    /* Reset to a sane state */
    sh2rec_htab_reset();
}

/* This function borrowed from the interpreter core */
void sh2rec_check_interrupts(SH2_struct *c) {
    if(c->NumberOfInterrupts != 0) {
        if(c->interrupts[c->NumberOfInterrupts-1].level > c->regs.SR.part.I) {
            c->regs.R[15] -= 4;
            MappedMemoryWriteLong(c->regs.R[15], c->regs.SR.all);
            c->regs.R[15] -= 4;
            MappedMemoryWriteLong(c->regs.R[15], c->regs.PC);
            c->regs.SR.part.I = c->interrupts[c->NumberOfInterrupts - 1].level;
            c->regs.PC = MappedMemoryReadLong(c->regs.VBR + (c->interrupts[c->NumberOfInterrupts-1].vector << 2));
            c->NumberOfInterrupts--;
            c->isSleeping = 0;
        }
    }
}

sh2rec_block_t *sh2rec_find_block(u32 pc) {
    sh2rec_block_t *b = sh2rec_htab_lookup(pc);

    if(!b) {
        b = sh2rec_htab_block_create(pc, 4096);
        sh2rec_rec_block(b);
    }

    return b;
}

SH2Interface_struct SH2Dynarec = {
    SH2CORE_DYNAREC,
    "SH2 -> SH4 Dynarec",

    sh2rec_init,                        /* Init */
    sh2rec_deinit,                      /* DeInit */
    sh2rec_reset,                       /* Reset */
    sh2rec_exec,                        /* Exec */

    SH2InterpreterGetRegisters,         /* GetRegisters */
    SH2InterpreterGetGPR,               /* GetGPR */
    SH2InterpreterGetSR,                /* GetSR */
    SH2InterpreterGetGBR,               /* GetGBR */
    SH2InterpreterGetVBR,               /* GetVBR */
    SH2InterpreterGetMACH,              /* GetMACH */
    SH2InterpreterGetMACL,              /* GetMACL */
    SH2InterpreterGetPR,                /* GetPR */
    SH2InterpreterGetPC,                /* GetPC */

    SH2InterpreterSetRegisters,         /* SetRegisters */
    SH2InterpreterSetGPR,               /* SetGPR */
    SH2InterpreterSetSR,                /* SetSR */
    SH2InterpreterSetGBR,               /* SetGBR */
    SH2InterpreterSetVBR,               /* SetVBR */
    SH2InterpreterSetMACH,              /* SetMACH */
    SH2InterpreterSetMACL,              /* SetMACL */
    SH2InterpreterSetPR,                /* SetPR */
    SH2InterpreterSetPC,                /* SetPC */

    SH2InterpreterSendInterrupt,        /* SendInterrupt */
    SH2InterpreterGetInterrupts,        /* GetInterrupts */
    SH2InterpreterSetInterrupts,        /* SetInterrupts */

    NULL                                /* WriteNotify */
};
