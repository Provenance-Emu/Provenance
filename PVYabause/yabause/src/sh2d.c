/*
 * sh2d
 * Bart Trzynadlowski, July 24, 2000
 * Public domain
 */

/*! \file sh2d.c
    \brief SH2 disassembler.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sh2core.h"
#include "sh2d.h"

#if 0
#include <curses.h>
#endif

#define ZERO_F  0       /* 0 format */
#define N_F     1       /* n format */
#define M_F     2       /* m format */
#define NM_F    3       /* nm format */
#define MD_F    4       /* md format */
#define ND4_F   5       /* nd4 format */
#define NMD_F   6       /* nmd format */
#define D_F     7       /* d format */
#define D12_F   8       /* d12 format */
#define ND8_F   9       /* nd8 format */
#define I_F     10      /* i format */
#define NI_F    11      /* ni format */

typedef struct
{
   int format;
   const char *mnem;
   unsigned short mask;   /* mask used to obtain opcode bits */
   unsigned short  bits;   /* opcode bits */
   int dat;    /* specific data for situation */
   int sh2;    /* SH-2 specific */
} i_descr;

i_descr trace[] = {
   { ZERO_F,       "clrt",                 0xffff, 0x8,    0,      0 },
   { ZERO_F,       "clrmac",               0xffff, 0x28,   0,      0 },
   { ZERO_F,       "div0u",                0xffff, 0x19,   0,      0 },
   { ZERO_F,       "nop",                  0xffff, 0x9,    0,      0 },
   { ZERO_F,       "rte",                  0xffff, 0x2b,   0,      0 },
   { ZERO_F,       "rts",                  0xffff, 0xb,    0,      0 },
   { ZERO_F,       "sett",                 0xffff, 0x18,   0,      0 },
   { ZERO_F,       "sleep",                0xffff, 0x1b,   0,      0 },
   { N_F,          "cmp/pl ((r%d)0x%08X)",          0xf0ff, 0x4015, 0,      0 },
   { N_F,          "cmp/pz ((r%d)0x%08X)",          0xf0ff, 0x4011, 0,      0 },
   { N_F,          "dt ((r%d)0x%08X)",              0xf0ff, 0x4010, 0,      1 },
   { N_F,          "movt ((r%d)0x%08X)",            0xf0ff, 0x0029, 0,      0 },
   { N_F,          "rotl ((r%d)0x%08X)",            0xf0ff, 0x4004, 0,      0 },
   { N_F,          "rotr ((r%d)0x%08X)",            0xf0ff, 0x4005, 0,      0 },
   { N_F,          "rotcl ((r%d)0x%08X)",           0xf0ff, 0x4024, 0,      0 },
   { N_F,          "rotcr ((r%d)0x%08X)",           0xf0ff, 0x4025, 0,      0 },
   { N_F,          "shal ((r%d)0x%08X)",            0xf0ff, 0x4020, 0,      0 },
   { N_F,          "shar ((r%d)0x%08X)",            0xf0ff, 0x4021, 0,      0 },
   { N_F,          "shll ((r%d)0x%08X)",            0xf0ff, 0x4000, 0,      0 },
   { N_F,          "shlr ((r%d)0x%08X)",            0xf0ff, 0x4001, 0,      0 },
   { N_F,          "shll2 ((r%d)0x%08X)",           0xf0ff, 0x4008, 0,      0 },
   { N_F,          "shlr2 ((r%d)0x%08X)",           0xf0ff, 0x4009, 0,      0 },
   { N_F,          "shll8 ((r%d)0x%08X)",           0xf0ff, 0x4018, 0,      0 },
   { N_F,          "shlr8 ((r%d)0x%08X)",           0xf0ff, 0x4019, 0,      0 },
   { N_F,          "shll16 ((r%d)0x%08X)",          0xf0ff, 0x4028, 0,      0 },
   { N_F,          "shlr16 ((r%d)0x%08X)",          0xf0ff, 0x4029, 0,      0 },
   { N_F,          "stc sr, ((r%d)0x%08X)",         0xf0ff, 0x0002, 0,      0 },
   { N_F,          "stc gbr, ((r%d)0x%08X)",        0xf0ff, 0x0012, 0,      0 },
   { N_F,          "stc vbr, ((r%d)0x%08X)",        0xf0ff, 0x0022, 0,      0 },
   { N_F,          "sts mach, ((r%d)0x%08X)",       0xf0ff, 0x000a, 0,      0 },
   { N_F,          "sts macl, ((r%d)0x%08X)",       0xf0ff, 0x001a, 0,      0 },
   { N_F,          "sts pr, ((r%d)0x%08X)",         0xf0ff, 0x002a, 0,      0 },
   { N_F,          "tas.b @((r%d)0x%08X)",          0xf0ff, 0x401b, 0,      0 },
   { N_F,          "stc.l sr, @-((r%d)0x%08X)",     0xf0ff, 0x4003, 0,      0 },
   { N_F,          "stc.l gbr, @-((r%d)0x%08X)",    0xf0ff, 0x4013, 0,      0 },
   { N_F,          "stc.l vbr, @-((r%d)0x%08X)",    0xf0ff, 0x4023, 0,      0 },
   { N_F,          "sts.l mach, @-((r%d)0x%08X)",   0xf0ff, 0x4002, 0,      0 },
   { N_F,          "sts.l macl, @-((r%d)0x%08X)",   0xf0ff, 0x4012, 0,      0 },
   { N_F,          "sts.l pr, @-((r%d)0x%08X)",     0xf0ff, 0x4022, 0,      0 },
   { M_F,          "ldc ((r%d)0x%08X), sr",         0xf0ff, 0x400e, 0,      0 },
   { M_F,          "ldc ((r%d)0x%08X), gbr",        0xf0ff, 0x401e, 0,      0 },
   { M_F,          "ldc ((r%d)0x%08X), vbr",        0xf0ff, 0x402e, 0,      0 },
   { M_F,          "lds ((r%d)0x%08X), mach",       0xf0ff, 0x400a, 0,      0 },
   { M_F,          "lds ((r%d)0x%08X), macl",       0xf0ff, 0x401a, 0,      0 },
   { M_F,          "lds ((r%d)0x%08X), pr",         0xf0ff, 0x402a, 0,      0 },
   { M_F,          "jmp @((r%d)0x%08X)",            0xf0ff, 0x402b, 0,      0 },
   { M_F,          "jsr @((r%d)0x%08X)",            0xf0ff, 0x400b, 0,      0 },
   { M_F,          "ldc.l @((r%d)0x%08X)+, sr",     0xf0ff, 0x4007, 0,      0 },
   { M_F,          "ldc.l @((r%d)0x%08X)+, gbr",    0xf0ff, 0x4017, 0,      0 },
   { M_F,          "ldc.l @((r%d)0x%08X)+, vbr",    0xf0ff, 0x4027, 0,      0 },
   { M_F,          "lds.l @((r%d)0x%08X)+, mach",   0xf0ff, 0x4006, 0,      0 },
   { M_F,          "lds.l @((r%d)0x%08X)+, macl",   0xf0ff, 0x4016, 0,      0 },
   { M_F,          "lds.l @((r%d)0x%08X)+, pr",     0xf0ff, 0x4026, 0,      0 },
   { M_F,          "braf ((r%d)0x%08X)",            0xf0ff, 0x0023, 0,      1 },
   { M_F,          "bsrf ((r%d)0x%08X)",            0xf0ff, 0x0003, 0,      1 },
   { NM_F,         "add ((r%d)0x%08X), ((r%d)0x%08X)",        0xf00f, 0x300c, 0,      0 },
   { NM_F,         "addc ((r%d)0x%08X), ((r%d)0x%08X)",       0xf00f, 0x300e, 0,      0 },
   { NM_F,         "addv ((r%d)0x%08X), ((r%d)0x%08X)",       0xf00f, 0x300f, 0,      0 },
   { NM_F,         "and ((r%d)0x%08X), ((r%d)0x%08X)",        0xf00f, 0x2009, 0,      0 },
   { NM_F,         "cmp/eq ((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x3000, 0,      0 },
   { NM_F,         "cmp/hs ((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x3002, 0,      0 },
   { NM_F,         "cmp/ge ((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x3003, 0,      0 },
   { NM_F,         "cmp/hi ((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x3006, 0,      0 },
   { NM_F,         "cmp/gt ((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x3007, 0,      0 },
   { NM_F,         "cmp/str ((r%d)0x%08X), ((r%d)0x%08X)",    0xf00f, 0x200c, 0,      0 },
   { NM_F,         "div1 ((r%d)0x%08X), ((r%d)0x%08X)",       0xf00f, 0x3004, 0,      0 },
   { NM_F,         "div0s ((r%d)0x%08X), ((r%d)0x%08X)",      0xf00f, 0x2007, 0,      0 },
   { NM_F,         "dmuls.l ((r%d)0x%08X), ((r%d)0x%08X)",    0xf00f, 0x300d, 0,      1 },
   { NM_F,         "dmulu.l ((r%d)0x%08X), ((r%d)0x%08X)",    0xf00f, 0x3005, 0,      1 },
   { NM_F,         "exts.b ((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x600e, 0,      0 },
   { NM_F,         "exts.w ((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x600f, 0,      0 },
   { NM_F,         "extu.b ((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x600c, 0,      0 },
   { NM_F,         "extu.w ((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x600d, 0,      0 },
   { NM_F,         "mov ((r%d)0x%08X), ((r%d)0x%08X)",        0xf00f, 0x6003, 0,      0 },
   { NM_F,         "mul.l ((r%d)0x%08X), ((r%d)0x%08X)",      0xf00f, 0x0007, 0,      1 },
   { NM_F,         "muls.w ((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x200f, 0,      0 },
   { NM_F,         "mulu.w ((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x200e, 0,      0 },
   { NM_F,         "neg ((r%d)0x%08X), ((r%d)0x%08X)",        0xf00f, 0x600b, 0,      0 },
   { NM_F,         "negc ((r%d)0x%08X), ((r%d)0x%08X)",       0xf00f, 0x600a, 0,      0 },
   { NM_F,         "not ((r%d)0x%08X), ((r%d)0x%08X)",        0xf00f, 0x6007, 0,      0 },
   { NM_F,         "or ((r%d)0x%08X), ((r%d)0x%08X)",         0xf00f, 0x200b, 0,      0 },
   { NM_F,         "sub ((r%d)0x%08X), ((r%d)0x%08X)",        0xf00f, 0x3008, 0,      0 },
   { NM_F,         "subc ((r%d)0x%08X), ((r%d)0x%08X)",       0xf00f, 0x300a, 0,      0 },
   { NM_F,         "subv ((r%d)0x%08X), ((r%d)0x%08X)",       0xf00f, 0x300b, 0,      0 },
   { NM_F,         "swap.b ((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x6008, 0,      0 },
   { NM_F,         "swap.w ((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x6009, 0,      0 },
   { NM_F,         "tst ((r%d)0x%08X), ((r%d)0x%08X)",        0xf00f, 0x2008, 0,      0 },
   { NM_F,         "xor ((r%d)0x%08X), ((r%d)0x%08X)",        0xf00f, 0x200a, 0,      0 },
   { NM_F,         "xtrct ((r%d)0x%08X), ((r%d)0x%08X)",      0xf00f, 0x200d, 0,      0 },
   { NM_F,         "mov.b ((r%d)0x%08X), @((r%d)0x%08X)",     0xf00f, 0x2000, 0,      0 },
   { NM_F,         "mov.w ((r%d)0x%08X), @((r%d)0x%08X)",     0xf00f, 0x2001, 0,      0 },
   { NM_F,         "mov.l ((r%d)0x%08X), @((r%d)0x%08X)",     0xf00f, 0x2002, 0,      0 },
   { NM_F,         "mov.b @((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x6000, 0,      0 },
   { NM_F,         "mov.w @((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x6001, 0,      0 },
   { NM_F,         "mov.l @((r%d)0x%08X), ((r%d)0x%08X)",     0xf00f, 0x6002, 0,      0 },
   { NM_F,         "mac.l @((r%d)0x%08X)+, @((r%d)0x%08X)+",  0xf00f, 0x000f, 0,      1 },
   { NM_F,         "mac.w @((r%d)0x%08X)+, @((r%d)0x%08X)+",  0xf00f, 0x400f, 0,      0 },
   { NM_F,         "mov.b @((r%d)0x%08X)+, ((r%d)0x%08X)",    0xf00f, 0x6004, 0,      0 },
   { NM_F,         "mov.w @((r%d)0x%08X)+, ((r%d)0x%08X)",    0xf00f, 0x6005, 0,      0 },
   { NM_F,         "mov.l @((r%d)0x%08X)+, ((r%d)0x%08X)",    0xf00f, 0x6006, 0,      0 },
   { NM_F,         "mov.b ((r%d)0x%08X), @-((r%d)0x%08X)",    0xf00f, 0x2004, 0,      0 },
   { NM_F,         "mov.w ((r%d)0x%08X), @-((r%d)0x%08X)",    0xf00f, 0x2005, 0,      0 },
   { NM_F,         "mov.l ((r%d)0x%08X), @-((r%d)0x%08X)",    0xf00f, 0x2006, 0,      0 },
   { NM_F,         "mov.b ((r%d)0x%08X), @(r0, ((r%d)0x%08X))", 0xf00f, 0x0004, 0,    0 },
   { NM_F,         "mov.w ((r%d)0x%08X), @(r0, ((r%d)0x%08X))", 0xf00f, 0x0005, 0,    0 },
   { NM_F,         "mov.l ((r%d)0x%08X), @(r0, ((r%d)0x%08X))", 0xf00f, 0x0006, 0,    0 },
   { NM_F,         "mov.b @(r0, ((r%d)0x%08X)), ((r%d)0x%08X)", 0xf00f, 0x000c, 0,    0 },
   { NM_F,         "mov.w @(r0, ((r%d)0x%08X)), ((r%d)0x%08X)", 0xf00f, 0x000d, 0,    0 },
   { NM_F,         "mov.l @(r0, ((r%d)0x%08X)), ((r%d)0x%08X)", 0xf00f, 0x000e, 0,    0 },
   { MD_F,         "mov.b @(0x%03X, ((r%d)0x%08X)), r0", 0xff00, 0x8400, 0, 0 },
   { MD_F,         "mov.w @(0x%03X, ((r%d)0x%08X)), r0", 0xff00, 0x8500, 0, 0 },
   { ND4_F,        "mov.b r0, @(0x%03X, ((r%d)0x%08X))", 0xff00, 0x8000, 0, 0 },
   { ND4_F,        "mov.w r0, @(0x%03X, ((r%d)0x%08X))", 0xff00, 0x8100, 0, 0 },
   { NMD_F,        "mov.l ((r%d)0x%08X), @(0x%03X, ((r%d)0x%08X))", 0xf000, 0x1000, 0,0 },
   { NMD_F,        "mov.l @(0x%03X, ((r%d)0x%08X)), ((r%d)0x%08X)", 0xf000, 0x5000, 0,0 },
   { D_F,          "mov.b r0, @(0x%03X, gbr)", 0xff00, 0xc000, 1, 0 },
   { D_F,          "mov.w r0, @(0x%03X, gbr)", 0xff00, 0xc100, 2, 0 },
   { D_F,          "mov.l r0, @(0x%03X, gbr)", 0xff00, 0xc200, 4, 0 },
   { D_F,          "mov.b @(0x%03X, gbr), r0", 0xff00, 0xc400, 1, 0 },
   { D_F,          "mov.w @(0x%03X, gbr), r0", 0xff00, 0xc500, 2, 0 },
   { D_F,          "mov.l @(0x%03X, gbr), r0", 0xff00, 0xc600, 4, 0 },
   { D_F,          "mova @(0x%03X, pc), r0", 0xff00, 0xc700, 4,   0 },
   { D_F,          "bf 0x%08X",           0xff00, 0x8b00, 5,      0 },
   { D_F,          "bf/s 0x%08X",         0xff00, 0x8f00, 5,      1 },
   { D_F,          "bt 0x%08X",           0xff00, 0x8900, 5,      0 },
   { D_F,          "bt/s 0x%08X",         0xff00, 0x8d00, 5,      1 },
   { D12_F,        "bra 0x%08X",          0xf000, 0xa000, 0,      0 },
   { D12_F,        "bsr 0x%08X",          0xf000, 0xb000, 0,      0 },
   { ND8_F,        "mov.w @(0x%03X, pc), ((r%d)0x%08X)", 0xf000, 0x9000, 2, 0 },
   { ND8_F,        "mov.l @(0x%03X, pc), ((r%d)0x%08X)", 0xf000, 0xd000, 4, 0 },
   { I_F,          "and.b #0x%02X, @(r0, gbr)", 0xff00, 0xcd00, 0,0 },
   { I_F,          "or.b #0x%02X, @(r0, gbr)",  0xff00, 0xcf00, 0,0 },
   { I_F,          "tst.b #0x%02X, @(r0, gbr)", 0xff00, 0xcc00, 0,0 },
   { I_F,          "xor.b #0x%02X, @(r0, gbr)", 0xff00, 0xce00, 0,0 },
   { I_F,          "and #0x%02X, r0",     0xff00, 0xc900, 0,      0 },
   { I_F,          "cmp/eq #0x%02X, r0",  0xff00, 0x8800, 0,      0 },
   { I_F,          "or #0x%02X, r0",      0xff00, 0xcb00, 0,      0 },
   { I_F,          "tst #0x%02X, r0",     0xff00, 0xc800, 0,      0 },
   { I_F,          "xor #0x%02X, r0",     0xff00, 0xca00, 0,      0 },
   { I_F,          "trapa #0x%X",         0xff00, 0xc300, 0,      0 },
   { NI_F,         "add #0x%02X, ((r%d)0x%08X)",    0xf000, 0x7000, 0,      0 },
   { NI_F,         "mov #0x%02X, ((r%d)0x%08X)",    0xf000, 0xe000, 0,      0 },
   { 0,            NULL,                   0,      0,      0,      0 }
};

i_descr tab[] = {
   { ZERO_F,       "clrt",                 0xffff, 0x8,    0,      0 },
   { ZERO_F,       "clrmac",               0xffff, 0x28,   0,      0 },
   { ZERO_F,       "div0u",                0xffff, 0x19,   0,      0 },
   { ZERO_F,       "nop",                  0xffff, 0x9,    0,      0 },
   { ZERO_F,       "rte",                  0xffff, 0x2b,   0,      0 },
   { ZERO_F,       "rts",                  0xffff, 0xb,    0,      0 },
   { ZERO_F,       "sett",                 0xffff, 0x18,   0,      0 },
   { ZERO_F,       "sleep",                0xffff, 0x1b,   0,      0 },
   { N_F,          "cmp/pl r%d",          0xf0ff, 0x4015, 0,      0 },
   { N_F,          "cmp/pz r%d",          0xf0ff, 0x4011, 0,      0 },
   { N_F,          "dt r%d",              0xf0ff, 0x4010, 0,      1 },
   { N_F,          "movt r%d",            0xf0ff, 0x0029, 0,      0 },
   { N_F,          "rotl r%d",            0xf0ff, 0x4004, 0,      0 },
   { N_F,          "rotr r%d",            0xf0ff, 0x4005, 0,      0 },
   { N_F,          "rotcl r%d",           0xf0ff, 0x4024, 0,      0 },
   { N_F,          "rotcr r%d",           0xf0ff, 0x4025, 0,      0 },
   { N_F,          "shal r%d",            0xf0ff, 0x4020, 0,      0 },
   { N_F,          "shar r%d",            0xf0ff, 0x4021, 0,      0 },
   { N_F,          "shll r%d",            0xf0ff, 0x4000, 0,      0 },
   { N_F,          "shlr r%d",            0xf0ff, 0x4001, 0,      0 },
   { N_F,          "shll2 r%d",           0xf0ff, 0x4008, 0,      0 },
   { N_F,          "shlr2 r%d",           0xf0ff, 0x4009, 0,      0 },
   { N_F,          "shll8 r%d",           0xf0ff, 0x4018, 0,      0 },
   { N_F,          "shlr8 r%d",           0xf0ff, 0x4019, 0,      0 },
   { N_F,          "shll16 r%d",          0xf0ff, 0x4028, 0,      0 },
   { N_F,          "shlr16 r%d",          0xf0ff, 0x4029, 0,      0 },
   { N_F,          "stc sr, r%d",         0xf0ff, 0x0002, 0,      0 },
   { N_F,          "stc gbr, r%d",        0xf0ff, 0x0012, 0,      0 },
   { N_F,          "stc vbr, r%d",        0xf0ff, 0x0022, 0,      0 },
   { N_F,          "sts mach, r%d",       0xf0ff, 0x000a, 0,      0 },
   { N_F,          "sts macl, r%d",       0xf0ff, 0x001a, 0,      0 },
   { N_F,          "sts pr, r%d",         0xf0ff, 0x002a, 0,      0 },
   { N_F,          "tas.b @r%d",          0xf0ff, 0x401b, 0,      0 },
   { N_F,          "stc.l sr, @-r%d",     0xf0ff, 0x4003, 0,      0 },
   { N_F,          "stc.l gbr, @-r%d",    0xf0ff, 0x4013, 0,      0 },
   { N_F,          "stc.l vbr, @-r%d",    0xf0ff, 0x4023, 0,      0 },
   { N_F,          "sts.l mach, @-r%d",   0xf0ff, 0x4002, 0,      0 },
   { N_F,          "sts.l macl, @-r%d",   0xf0ff, 0x4012, 0,      0 },
   { N_F,          "sts.l pr, @-r%d",     0xf0ff, 0x4022, 0,      0 },
   { M_F,          "ldc r%d, sr",         0xf0ff, 0x400e, 0,      0 },
   { M_F,          "ldc r%d, gbr",        0xf0ff, 0x401e, 0,      0 },
   { M_F,          "ldc r%d, vbr",        0xf0ff, 0x402e, 0,      0 },
   { M_F,          "lds r%d, mach",       0xf0ff, 0x400a, 0,      0 },
   { M_F,          "lds r%d, macl",       0xf0ff, 0x401a, 0,      0 },
   { M_F,          "lds r%d, pr",         0xf0ff, 0x402a, 0,      0 },
   { M_F,          "jmp @r%d",            0xf0ff, 0x402b, 0,      0 },
   { M_F,          "jsr @r%d",            0xf0ff, 0x400b, 0,      0 },
   { M_F,          "ldc.l @r%d+, sr",     0xf0ff, 0x4007, 0,      0 },
   { M_F,          "ldc.l @r%d+, gbr",    0xf0ff, 0x4017, 0,      0 },
   { M_F,          "ldc.l @r%d+, vbr",    0xf0ff, 0x4027, 0,      0 },
   { M_F,          "lds.l @r%d+, mach",   0xf0ff, 0x4006, 0,      0 },
   { M_F,          "lds.l @r%d+, macl",   0xf0ff, 0x4016, 0,      0 },
   { M_F,          "lds.l @r%d+, pr",     0xf0ff, 0x4026, 0,      0 },
   { M_F,          "braf r%d",            0xf0ff, 0x0023, 0,      1 },
   { M_F,          "bsrf r%d",            0xf0ff, 0x0003, 0,      1 },
   { NM_F,         "add r%d, r%d",        0xf00f, 0x300c, 0,      0 },
   { NM_F,         "addc r%d, r%d",       0xf00f, 0x300e, 0,      0 },
   { NM_F,         "addv r%d, r%d",       0xf00f, 0x300f, 0,      0 },
   { NM_F,         "and r%d, r%d",        0xf00f, 0x2009, 0,      0 },
   { NM_F,         "cmp/eq r%d, r%d",     0xf00f, 0x3000, 0,      0 },
   { NM_F,         "cmp/hs r%d, r%d",     0xf00f, 0x3002, 0,      0 },
   { NM_F,         "cmp/ge r%d, r%d",     0xf00f, 0x3003, 0,      0 },
   { NM_F,         "cmp/hi r%d, r%d",     0xf00f, 0x3006, 0,      0 },
   { NM_F,         "cmp/gt r%d, r%d",     0xf00f, 0x3007, 0,      0 },
   { NM_F,         "cmp/str r%d, r%d",    0xf00f, 0x200c, 0,      0 },
   { NM_F,         "div1 r%d, r%d",       0xf00f, 0x3004, 0,      0 },
   { NM_F,         "div0s r%d, r%d",      0xf00f, 0x2007, 0,      0 },
   { NM_F,         "dmuls.l r%d, r%d",    0xf00f, 0x300d, 0,      1 },
   { NM_F,         "dmulu.l r%d, r%d",    0xf00f, 0x3005, 0,      1 },
   { NM_F,         "exts.b r%d, r%d",     0xf00f, 0x600e, 0,      0 },
   { NM_F,         "exts.w r%d, r%d",     0xf00f, 0x600f, 0,      0 },
   { NM_F,         "extu.b r%d, r%d",     0xf00f, 0x600c, 0,      0 },
   { NM_F,         "extu.w r%d, r%d",     0xf00f, 0x600d, 0,      0 },
   { NM_F,         "mov r%d, r%d",        0xf00f, 0x6003, 0,      0 },
   { NM_F,         "mul.l r%d, r%d",      0xf00f, 0x0007, 0,      1 },
   { NM_F,         "muls.w r%d, r%d",     0xf00f, 0x200f, 0,      0 },
   { NM_F,         "mulu.w r%d, r%d",     0xf00f, 0x200e, 0,      0 },
   { NM_F,         "neg r%d, r%d",        0xf00f, 0x600b, 0,      0 },
   { NM_F,         "negc r%d, r%d",       0xf00f, 0x600a, 0,      0 },
   { NM_F,         "not r%d, r%d",        0xf00f, 0x6007, 0,      0 },
   { NM_F,         "or r%d, r%d",         0xf00f, 0x200b, 0,      0 },
   { NM_F,         "sub r%d, r%d",        0xf00f, 0x3008, 0,      0 },
   { NM_F,         "subc r%d, r%d",       0xf00f, 0x300a, 0,      0 },
   { NM_F,         "subv r%d, r%d",       0xf00f, 0x300b, 0,      0 },
   { NM_F,         "swap.b r%d, r%d",     0xf00f, 0x6008, 0,      0 },
   { NM_F,         "swap.w r%d, r%d",     0xf00f, 0x6009, 0,      0 },
   { NM_F,         "tst r%d, r%d",        0xf00f, 0x2008, 0,      0 },
   { NM_F,         "xor r%d, r%d",        0xf00f, 0x200a, 0,      0 },
   { NM_F,         "xtrct r%d, r%d",      0xf00f, 0x200d, 0,      0 },
   { NM_F,         "mov.b r%d, @r%d",     0xf00f, 0x2000, 0,      0 },
   { NM_F,         "mov.w r%d, @r%d",     0xf00f, 0x2001, 0,      0 },
   { NM_F,         "mov.l r%d, @r%d",     0xf00f, 0x2002, 0,      0 },
   { NM_F,         "mov.b @r%d, r%d",     0xf00f, 0x6000, 0,      0 },
   { NM_F,         "mov.w @r%d, r%d",     0xf00f, 0x6001, 0,      0 },
   { NM_F,         "mov.l @r%d, r%d",     0xf00f, 0x6002, 0,      0 },
   { NM_F,         "mac.l @r%d+, @r%d+",  0xf00f, 0x000f, 0,      1 },
   { NM_F,         "mac.w @r%d+, @r%d+",  0xf00f, 0x400f, 0,      0 },
   { NM_F,         "mov.b @r%d+, r%d",    0xf00f, 0x6004, 0,      0 },
   { NM_F,         "mov.w @r%d+, r%d",    0xf00f, 0x6005, 0,      0 },
   { NM_F,         "mov.l @r%d+, r%d",    0xf00f, 0x6006, 0,      0 },
   { NM_F,         "mov.b r%d, @-r%d",    0xf00f, 0x2004, 0,      0 },
   { NM_F,         "mov.w r%d, @-r%d",    0xf00f, 0x2005, 0,      0 },
   { NM_F,         "mov.l r%d, @-r%d",    0xf00f, 0x2006, 0,      0 },
   { NM_F,         "mov.b r%d, @(r0, r%d)", 0xf00f, 0x0004, 0,    0 },
   { NM_F,         "mov.w r%d, @(r0, r%d)", 0xf00f, 0x0005, 0,    0 },
   { NM_F,         "mov.l r%d, @(r0, r%d)", 0xf00f, 0x0006, 0,    0 },
   { NM_F,         "mov.b @(r0, r%d), r%d", 0xf00f, 0x000c, 0,    0 },
   { NM_F,         "mov.w @(r0, r%d), r%d", 0xf00f, 0x000d, 0,    0 },
   { NM_F,         "mov.l @(r0, r%d), r%d", 0xf00f, 0x000e, 0,    0 },
   { MD_F,         "mov.b @(0x%03X, r%d), r0", 0xff00, 0x8400, 0, 0 },
   { MD_F,         "mov.w @(0x%03X, r%d), r0", 0xff00, 0x8500, 0, 0 },
   { ND4_F,        "mov.b r0, @(0x%03X, r%d)", 0xff00, 0x8000, 0, 0 },
   { ND4_F,        "mov.w r0, @(0x%03X, r%d)", 0xff00, 0x8100, 0, 0 },
   { NMD_F,        "mov.l r%d, @(0x%03X, r%d)", 0xf000, 0x1000, 0,0 },
   { NMD_F,        "mov.l @(0x%03X, r%d), r%d", 0xf000, 0x5000, 0,0 },
   { D_F,          "mov.b r0, @(0x%03X, gbr)", 0xff00, 0xc000, 1, 0 },
   { D_F,          "mov.w r0, @(0x%03X, gbr)", 0xff00, 0xc100, 2, 0 },
   { D_F,          "mov.l r0, @(0x%03X, gbr)", 0xff00, 0xc200, 4, 0 },
   { D_F,          "mov.b @(0x%03X, gbr), r0", 0xff00, 0xc400, 1, 0 },
   { D_F,          "mov.w @(0x%03X, gbr), r0", 0xff00, 0xc500, 2, 0 },
   { D_F,          "mov.l @(0x%03X, gbr), r0", 0xff00, 0xc600, 4, 0 },
   { D_F,          "mova @(0x%03X, pc), r0", 0xff00, 0xc700, 4,   0 },
   { D_F,          "bf 0x%08X",           0xff00, 0x8b00, 5,      0 },
   { D_F,          "bf/s 0x%08X",         0xff00, 0x8f00, 5,      1 },
   { D_F,          "bt 0x%08X",           0xff00, 0x8900, 5,      0 },
   { D_F,          "bt/s 0x%08X",         0xff00, 0x8d00, 5,      1 },
   { D12_F,        "bra 0x%08X",          0xf000, 0xa000, 0,      0 },
   { D12_F,        "bsr 0x%08X",          0xf000, 0xb000, 0,      0 },
   { ND8_F,        "mov.w @(0x%03X, pc), r%d", 0xf000, 0x9000, 2, 0 },
   { ND8_F,        "mov.l @(0x%03X, pc), r%d", 0xf000, 0xd000, 4, 0 },
   { I_F,          "and.b #0x%02X, @(r0, gbr)", 0xff00, 0xcd00, 0,0 },
   { I_F,          "or.b #0x%02X, @(r0, gbr)",  0xff00, 0xcf00, 0,0 },
   { I_F,          "tst.b #0x%02X, @(r0, gbr)", 0xff00, 0xcc00, 0,0 },
   { I_F,          "xor.b #0x%02X, @(r0, gbr)", 0xff00, 0xce00, 0,0 },
   { I_F,          "and #0x%02X, r0",     0xff00, 0xc900, 0,      0 },
   { I_F,          "cmp/eq #0x%02X, r0",  0xff00, 0x8800, 0,      0 },
   { I_F,          "or #0x%02X, r0",      0xff00, 0xcb00, 0,      0 },
   { I_F,          "tst #0x%02X, r0",     0xff00, 0xc800, 0,      0 },
   { I_F,          "xor #0x%02X, r0",     0xff00, 0xca00, 0,      0 },
   { I_F,          "trapa #0x%X",         0xff00, 0xc300, 0,      0 },
   { NI_F,         "add #0x%02X, r%d",    0xf000, 0x7000, 0,      0 },
   { NI_F,         "mov #0x%02X, r%d",    0xf000, 0xe000, 0,      0 },
   { 0,            NULL,                   0,      0,      0,      0 }
};

/*
 * SH2Disasm(): SH-1/SH-2 disassembler routine. If mode = 0 then SH-2 mode,
 *              otherwise SH-1 mode
 */
 
void SH2Disasm(u32 v_addr, u16 op, int mode, sh2regs_struct *regs, char *string)
{
   int i;
   sprintf(string,"0x%08X: ", (unsigned int)v_addr);
   string+=strlen(string);

   //TODO : Clean this up and not be lazy :)
   if (regs != NULL)
   {
		for (i = 0; trace[i].mnem != NULL; i++)   /* 0 format */
	   {
		   if ((op & trace[i].mask) == trace[i].bits)
		   {
			   int rtype_1 = (op >> 4) & 0xf;
			   int rtype_2 = (op >> 8) & 0xf;

			   if (trace[i].sh2 && mode) /* if SH-1 mode, no SH-2 */
				   sprintf(string, "unrecognized");
			   else if (trace[i].format == ZERO_F)
				   sprintf(string, "%s", trace[i].mnem);
			   else if (trace[i].format == N_F)
				   sprintf(string, trace[i].mnem, rtype_2, regs->R[rtype_2]);
			   else if (trace[i].format == M_F)
				   sprintf(string, trace[i].mnem, rtype_2, regs->R[rtype_2]);
			   else if (trace[i].format == NM_F)
				   sprintf(string, trace[i].mnem, rtype_1, regs->R[rtype_1], rtype_2, regs->R[rtype_2]);
			   else if (trace[i].format == MD_F)
			   {
				   if (op & 0x100)
					   sprintf(string, trace[i].mnem, (op & 0xf) * 2, rtype_1, regs->R[rtype_1]);
				   else
					   sprintf(string, trace[i].mnem, op & 0xf, rtype_1, regs->R[rtype_1]);
			   }
			   else if (trace[i].format == ND4_F)
			   {
				   if (op & 0x100)
					   sprintf(string, trace[i].mnem, (op & 0xf) * 2, rtype_1, regs->R[rtype_1]);
				   else
					   sprintf(string, trace[i].mnem, (op & 0xf), rtype_1, regs->R[rtype_1]);
			   }
			   else if (trace[i].format == NMD_F)
			   {
				   if ((op & 0xf000) == 0x1000)
					   sprintf(string, trace[i].mnem, rtype_1, regs->R[rtype_1], (op & 0xf) * 4, rtype_2, regs->R[rtype_2]);
				   else
					   sprintf(string, trace[i].mnem, (op & 0xf) * 4, rtype_1, regs->R[rtype_1], rtype_2, regs->R[rtype_2]);
			   }
			   else if (trace[i].format == D_F)
			   {
				   if (trace[i].dat <= 4)
				   {
					   if ((op & 0xff00) == 0xc700)
					   {
						   sprintf(string, trace[i].mnem, (op & 0xff) * trace[i].dat + 4);
						   string += strlen(string);
						   sprintf(string, " ; 0x%08X",
							   ((op & 0xff) * trace[i].dat + 4 + (unsigned int)v_addr)
							   & 0xfffffffc);
					   }
					   else
						   sprintf(string, trace[i].mnem, (op & 0xff) * trace[i].dat);
				   }
				   else
				   {
					   if (op & 0x80)  /* sign extend */
						   sprintf(string, trace[i].mnem, (((op & 0xff) + 0xffffff00) * 2) + v_addr + 4);
					   else
						   sprintf(string, trace[i].mnem, ((op & 0xff) * 2) + v_addr + 4);
				   }
			   }
			   else if (trace[i].format == D12_F)
			   {
				   if (op & 0x800)         /* sign extend */
					   sprintf(string, trace[i].mnem, ((op & 0xfff) + 0xfffff000) * 2 + v_addr + 4);
				   else
					   sprintf(string, trace[i].mnem, (op & 0xfff) * 2 + v_addr + 4);
			   }
			   else if (trace[i].format == ND8_F)
			   {
				   if ((op & 0xf000) == 0x9000)    /* .W */
				   {
					   sprintf(string, trace[i].mnem, (op & 0xff) * trace[i].dat + 4, rtype_2), regs->R[rtype_2];
					   string += strlen(string);
					   sprintf(string, " ; 0x%08X", ((op & 0xff) * trace[i].dat + 4 + (unsigned int)v_addr));
				   }
				   else                            /* .L */
				   {
					   sprintf(string, trace[i].mnem, (op & 0xff) * trace[i].dat + 4, rtype_2, regs->R[rtype_2]);
					   string += strlen(string);
					   sprintf(string, " ; 0x%08X", ((op & 0xff) * trace[i].dat + 4 + (unsigned int)v_addr) & 0xfffffffc);
				   }
			   }
			   else if (trace[i].format == I_F)
				   sprintf(string, trace[i].mnem, op & 0xff);
			   else if (trace[i].format == NI_F)
				   sprintf(string, trace[i].mnem, op & 0xff, rtype_2, regs->R[rtype_2]);
			   else
				   sprintf(string, "unrecognized");
			   return;
		   }
	   }
   }
   else
   {
	   for (i = 0; tab[i].mnem != NULL; i++)   /* 0 format */
	   {
		   if ((op & tab[i].mask) == tab[i].bits)
		   {
			   if (tab[i].sh2 && mode) /* if SH-1 mode, no SH-2 */
				   sprintf(string, "unrecognized");
			   else if (tab[i].format == ZERO_F)
				   sprintf(string, "%s", tab[i].mnem);
			   else if (tab[i].format == N_F)
				   sprintf(string, tab[i].mnem, (op >> 8) & 0xf);
			   else if (tab[i].format == M_F)
				   sprintf(string, tab[i].mnem, (op >> 8) & 0xf);
			   else if (tab[i].format == NM_F)
				   sprintf(string, tab[i].mnem, (op >> 4) & 0xf, (op >> 8) & 0xf);
			   else if (tab[i].format == MD_F)
			   {
				   if (op & 0x100)
					   sprintf(string, tab[i].mnem, (op & 0xf) * 2, (op >> 4) & 0xf);
				   else
					   sprintf(string, tab[i].mnem, op & 0xf, (op >> 4) & 0xf);
			   }
			   else if (tab[i].format == ND4_F)
			   {
				   if (op & 0x100)
					   sprintf(string, tab[i].mnem, (op & 0xf) * 2, (op >> 4) & 0xf);
				   else
					   sprintf(string, tab[i].mnem, (op & 0xf), (op >> 4) & 0xf);
			   }
			   else if (tab[i].format == NMD_F)
			   {
				   if ((op & 0xf000) == 0x1000)
					   sprintf(string, tab[i].mnem, (op >> 4) & 0xf,
					   (op & 0xf) * 4, (op >> 8) & 0xf);
				   else
					   sprintf(string, tab[i].mnem, (op & 0xf) * 4,
					   (op >> 4) & 0xf, (op >> 8) & 0xf);
			   }
			   else if (tab[i].format == D_F)
			   {
				   if (tab[i].dat <= 4)
				   {
					   if ((op & 0xff00) == 0xc700)
					   {
						   sprintf(string, tab[i].mnem, (op & 0xff) * tab[i].dat + 4);
						   string += strlen(string);
						   sprintf(string, " ; 0x%08X",
							   ((op & 0xff) * tab[i].dat + 4 + (unsigned int)v_addr)
							   & 0xfffffffc);
					   }
					   else
						   sprintf(string, tab[i].mnem, (op & 0xff) * tab[i].dat);
				   }
				   else
				   {
					   if (op & 0x80)  /* sign extend */
						   sprintf(string, tab[i].mnem, (((op & 0xff) + 0xffffff00) * 2) + v_addr + 4);
					   else
						   sprintf(string, tab[i].mnem, ((op & 0xff) * 2) + v_addr + 4);
				   }
			   }
			   else if (tab[i].format == D12_F)
			   {
				   if (op & 0x800)         /* sign extend */
					   sprintf(string, tab[i].mnem, ((op & 0xfff) + 0xfffff000) * 2 + v_addr + 4);
				   else
					   sprintf(string, tab[i].mnem, (op & 0xfff) * 2 + v_addr + 4);
			   }
			   else if (tab[i].format == ND8_F)
			   {
				   if ((op & 0xf000) == 0x9000)    /* .W */
				   {
					   sprintf(string, tab[i].mnem, (op & 0xff) * tab[i].dat + 4, (op >> 8) & 0xf);
					   string += strlen(string);
					   sprintf(string, " ; 0x%08X", (op & 0xff) * tab[i].dat + 4 + (unsigned int)v_addr);
				   }
				   else                            /* .L */
				   {
					   sprintf(string, tab[i].mnem, (op & 0xff) * tab[i].dat + 4,
						   (op >> 8) & 0xf);
					   string += strlen(string);
					   sprintf(string, " ; 0x%08X",
						   ((op & 0xff) * tab[i].dat + 4 + (unsigned int)v_addr)
						   & 0xfffffffc);
				   }
			   }
			   else if (tab[i].format == I_F)
				   sprintf(string, tab[i].mnem, op & 0xff);
			   else if (tab[i].format == NI_F)
				   sprintf(string, tab[i].mnem, op & 0xff, (op >> 8) & 0xf);
			   else
				   sprintf(string, "unrecognized");
			   return;
		   }
	   }
   }
       
   sprintf(string,"unrecognized");
}
