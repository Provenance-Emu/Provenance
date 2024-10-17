/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - idec.c                                                  *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2018 Bobby Smiles                                       *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#include "idec.h"

#include "r4300_core.h"

#include <assert.h>

/* define registers/small constants instruction fields */
#define U53_NONE    U53(IDEC_REGTYPE_NONE,   0)

#define U53_SA      U53(IDEC_REGTYPE_NONE,   6)
#define U53_RD      U53(IDEC_REGTYPE_GPR,   11)
#define U53_RT      U53(IDEC_REGTYPE_GPR,   16)
#define U53_RS      U53(IDEC_REGTYPE_GPR,   21)

#define U53_FD      U53(IDEC_REGTYPE_FPR,    6)
#define U53_FDS     U53(IDEC_REGTYPE_FPR32,  6)
#define U53_FDD     U53(IDEC_REGTYPE_FPR64,  6)
#define U53_FDW     U53(IDEC_REGTYPE_FPR32,  6)
#define U53_FDL     U53(IDEC_REGTYPE_FPR64,  6)
#define U53_FCR     U53(IDEC_REGTYPE_FCR,   11)
#define U53_FS      U53(IDEC_REGTYPE_FPR,   11)
#define U53_FS32    U53(IDEC_REGTYPE_FPR32, 11)
#define U53_FS64    U53(IDEC_REGTYPE_FPR64, 11)
#define U53_FT      U53(IDEC_REGTYPE_FPR,   16)
#define U53_FT32    U53(IDEC_REGTYPE_FPR32, 16)
#define U53_FT64    U53(IDEC_REGTYPE_FPR64, 16)
#define U53_FMT     U53(IDEC_REGTYPE_NONE,  21)

#define U53_CACHEOP U53(IDEC_REGTYPE_NONE,  16)
#define U53_CPR0    U53(IDEC_REGTYPE_CPR0,  11)

/* disabled because not part of r4300 */
#define U53_CCR0    U53(IDEC_REGTYPE_NONE,  11)
#define U53_CCR2    U53(IDEC_REGTYPE_NONE,  11)
#define U53_CPR2D   U53(IDEC_REGTYPE_NONE,  11)
#define U53_CPR2T   U53(IDEC_REGTYPE_NONE,  16)


/* define immediate instruction fields */
/*                       imask,  smask, lshift */
#define IMM_NONE             0,      0,  0
#define IMM_OFFSET      0xffff, 0x8000,  0
#define IMM_OFFSET4     0xffff, 0x8000,  2
#define IMM_LUI         0xffff, 0x8000, 16
#define IMM_SIMM        0xffff, 0x8000,  0
#define IMM_ZIMM        0xffff, 0x0000,  0
#define IMM_TARGET   0x3ffffff, 0x0000,  2

/* define instruction decoders   IMM,           RD/FD,     RT/FT,       RS/FS,    FMT/SA  */
#define IDEC_NONE                IMM_NONE,    { U53_NONE,  U53_NONE,    U53_NONE, U53_NONE }
#define IDEC_CACHEOP_BASE_OFFSET IMM_OFFSET,  { U53_NONE,  U53_CACHEOP, U53_RS,   U53_NONE }
#define IDEC_FD_FS_FMT           IMM_NONE,    { U53_FD,    U53_NONE,    U53_FS,   U53_FMT  }
#define IDEC_FDS_FS_FMT          IMM_NONE,    { U53_FDS,   U53_NONE,    U53_FS,   U53_FMT  }
#define IDEC_FDD_FS_FMT          IMM_NONE,    { U53_FDD,   U53_NONE,    U53_FS,   U53_FMT  }
#define IDEC_FDW_FS_FMT          IMM_NONE,    { U53_FDW,   U53_NONE,    U53_FS,   U53_FMT  }
#define IDEC_FDL_FS_FMT          IMM_NONE,    { U53_FDL,   U53_NONE,    U53_FS,   U53_FMT  }
#define IDEC_FD_FS_FT_FMT        IMM_NONE,    { U53_FD,    U53_FT,      U53_FS,   U53_FMT  }
#define IDEC_FS_FT_FMT           IMM_NONE,    { U53_NONE,  U53_FT,      U53_FS,   U53_FMT  }
#define IDEC_OFFSET              IMM_OFFSET4, { U53_NONE,  U53_NONE,    U53_NONE, U53_NONE }
#define IDEC_RD                  IMM_NONE,    { U53_RD,    U53_NONE,    U53_NONE, U53_NONE }
#define IDEC_RD_RS               IMM_NONE,    { U53_RD,    U53_NONE,    U53_RS,   U53_NONE }
#define IDEC_RD_RS_RT            IMM_NONE,    { U53_RD,    U53_RT,      U53_RS,   U53_NONE }
#define IDEC_RD_RT_RS            IMM_NONE,    { U53_RD,    U53_RT,      U53_RS,   U53_NONE }
#define IDEC_RD_RT_SA            IMM_NONE,    { U53_RD,    U53_RT,      U53_NONE, U53_SA   }
#define IDEC_RS                  IMM_NONE,    { U53_NONE,  U53_NONE,    U53_RS,   U53_NONE }
#define IDEC_RS_OFFSET           IMM_OFFSET4, { U53_NONE,  U53_NONE,    U53_RS,   U53_NONE }
#define IDEC_RS_RT               IMM_NONE,    { U53_NONE,  U53_RT,      U53_RS,   U53_NONE }
#define IDEC_RS_RT_OFFSET        IMM_OFFSET4, { U53_NONE,  U53_RT,      U53_RS,   U53_NONE }
#define IDEC_RS_SIMM             IMM_SIMM,    { U53_NONE,  U53_NONE,    U53_RS,   U53_NONE }
#define IDEC_RT_BASE_OFFSET      IMM_OFFSET,  { U53_NONE,  U53_RT,      U53_RS,   U53_NONE }
#define IDEC_CPR2_BASE_OFFSET    IMM_OFFSET,  { U53_NONE,  U53_CPR2T,   U53_RS,   U53_NONE }
#define IDEC_FT32_BASE_OFFSET    IMM_OFFSET,  { U53_NONE,  U53_FT32,    U53_RS,   U53_NONE }
#define IDEC_FT64_BASE_OFFSET    IMM_OFFSET,  { U53_NONE,  U53_FT64,    U53_RS,   U53_NONE }
#define IDEC_RT_LUI              IMM_LUI,     { U53_NONE,  U53_RT,      U53_NONE, U53_NONE }
#define IDEC_RT_CPR0             IMM_NONE,    { U53_CPR0,  U53_RT,      U53_NONE, U53_NONE }
#define IDEC_RT_FS32             IMM_NONE,    { U53_FS32,  U53_RT,      U53_NONE, U53_NONE }
#define IDEC_RT_FS64             IMM_NONE,    { U53_FS64,  U53_RT,      U53_NONE, U53_NONE }
#define IDEC_RT_CPR2             IMM_NONE,    { U53_CPR2D, U53_RT,      U53_NONE, U53_NONE }
#define IDEC_RT_CCR0             IMM_NONE,    { U53_CCR0,  U53_RT,      U53_NONE, U53_NONE }
#define IDEC_RT_FCR              IMM_NONE,    { U53_FCR,   U53_RT,      U53_NONE, U53_NONE }
#define IDEC_RT_CCR2             IMM_NONE,    { U53_CCR2,  U53_RT,      U53_NONE, U53_NONE }
#define IDEC_RT_RS_SIMM          IMM_SIMM,    { U53_NONE,  U53_RT,      U53_RS,   U53_NONE }
#define IDEC_RT_RS_ZIMM          IMM_ZIMM,    { U53_NONE,  U53_RT,      U53_RS,   U53_NONE }
#define IDEC_TARGET              IMM_TARGET,  { U53_NONE,  U53_NONE,    U53_NONE, U53_NONE }



#define RESERVED    { R4300_OP_RESERVED,    IDEC_NONE }
#define ADD         { R4300_OP_ADD,         IDEC_RD_RS_RT }
#define ADDI        { R4300_OP_ADDI,        IDEC_RT_RS_SIMM }
#define ADDIU       { R4300_OP_ADDIU,       IDEC_RT_RS_SIMM }
#define ADDU        { R4300_OP_ADDU,        IDEC_RD_RS_RT }
#define AND         { R4300_OP_AND,         IDEC_RD_RS_RT }
#define ANDI        { R4300_OP_ANDI,        IDEC_RT_RS_ZIMM }
#define BC0F        { R4300_OP_BC0F,        IDEC_OFFSET }
#define BC1F        { R4300_OP_BC1F,        IDEC_OFFSET }
#define BC2F        { R4300_OP_BC2F,        IDEC_OFFSET }
#define BC0FL       { R4300_OP_BC0FL,       IDEC_OFFSET }
#define BC1FL       { R4300_OP_BC1FL,       IDEC_OFFSET }
#define BC2FL       { R4300_OP_BC2FL,       IDEC_OFFSET }
#define BC0T        { R4300_OP_BC0T,        IDEC_OFFSET }
#define BC1T        { R4300_OP_BC1T,        IDEC_OFFSET }
#define BC2T        { R4300_OP_BC2T,        IDEC_OFFSET }
#define BC0TL       { R4300_OP_BC0TL,       IDEC_OFFSET }
#define BC1TL       { R4300_OP_BC1TL,       IDEC_OFFSET }
#define BC2TL       { R4300_OP_BC2TL,       IDEC_OFFSET }
#define BEQ         { R4300_OP_BEQ,         IDEC_RS_RT_OFFSET }
#define BEQL        { R4300_OP_BEQL,        IDEC_RS_RT_OFFSET }
#define BGEZ        { R4300_OP_BGEZ,        IDEC_RS_OFFSET }
#define BGEZAL      { R4300_OP_BGEZAL,      IDEC_RS_OFFSET }
#define BGEZALL     { R4300_OP_BGEZALL,     IDEC_RS_OFFSET }
#define BGEZL       { R4300_OP_BGEZL,       IDEC_RS_OFFSET }
#define BGTZ        { R4300_OP_BGTZ,        IDEC_RS_OFFSET }
#define BGTZL       { R4300_OP_BGTZL,       IDEC_RS_OFFSET }
#define BLEZ        { R4300_OP_BLEZ,        IDEC_RS_OFFSET }
#define BLEZL       { R4300_OP_BLEZL,       IDEC_RS_OFFSET }
#define BLTZ        { R4300_OP_BLTZ,        IDEC_RS_OFFSET }
#define BLTZAL      { R4300_OP_BLTZAL,      IDEC_RS_OFFSET }
#define BLTZALL     { R4300_OP_BLTZALL,     IDEC_RS_OFFSET }
#define BLTZL       { R4300_OP_BLTZL,       IDEC_RS_OFFSET }
#define BNE         { R4300_OP_BNE,         IDEC_RS_RT_OFFSET }
#define BNEL        { R4300_OP_BNEL,        IDEC_RS_RT_OFFSET }
#define BREAK       { R4300_OP_BREAK,       IDEC_NONE }
#define CACHE       { R4300_OP_CACHE,       IDEC_CACHEOP_BASE_OFFSET }
#define CFC0        { R4300_OP_CFC0,        IDEC_RT_CCR0 }
#define CFC1        { R4300_OP_CFC1,        IDEC_RT_FCR }
#define CFC2        { R4300_OP_CFC2,        IDEC_RT_CCR2 }
#define CP1_ABS     { R4300_OP_CP1_ABS,     IDEC_FD_FS_FMT }
#define CP1_ADD     { R4300_OP_CP1_ADD,     IDEC_FD_FS_FT_FMT }
#define CP1_C_EQ    { R4300_OP_CP1_C_EQ,    IDEC_FS_FT_FMT }
#define CP1_C_F     { R4300_OP_CP1_C_F,     IDEC_FS_FT_FMT }
#define CP1_C_LE    { R4300_OP_CP1_C_LE,    IDEC_FS_FT_FMT }
#define CP1_C_LT    { R4300_OP_CP1_C_LT,    IDEC_FS_FT_FMT }
#define CP1_C_NGE   { R4300_OP_CP1_C_NGE,   IDEC_FS_FT_FMT }
#define CP1_C_NGLE  { R4300_OP_CP1_C_NGLE,  IDEC_FS_FT_FMT }
#define CP1_C_NGL   { R4300_OP_CP1_C_NGL,   IDEC_FS_FT_FMT }
#define CP1_C_NGT   { R4300_OP_CP1_C_NGT,   IDEC_FS_FT_FMT }
#define CP1_C_OLE   { R4300_OP_CP1_C_OLE,   IDEC_FS_FT_FMT }
#define CP1_C_OLT   { R4300_OP_CP1_C_OLT,   IDEC_FS_FT_FMT }
#define CP1_C_SEQ   { R4300_OP_CP1_C_SEQ,   IDEC_FS_FT_FMT }
#define CP1_C_SF    { R4300_OP_CP1_C_SF,    IDEC_FS_FT_FMT }
#define CP1_C_UEQ   { R4300_OP_CP1_C_UEQ,   IDEC_FS_FT_FMT }
#define CP1_C_ULE   { R4300_OP_CP1_C_ULE,   IDEC_FS_FT_FMT }
#define CP1_C_ULT   { R4300_OP_CP1_C_ULT,   IDEC_FS_FT_FMT }
#define CP1_C_UN    { R4300_OP_CP1_C_UN,    IDEC_FS_FT_FMT }
#define CP1_CEIL_L  { R4300_OP_CP1_CEIL_L,  IDEC_FDL_FS_FMT }
#define CP1_CEIL_W  { R4300_OP_CP1_CEIL_W,  IDEC_FDW_FS_FMT }
#define CP1_CVT_D   { R4300_OP_CP1_CVT_D,   IDEC_FDD_FS_FMT }
#define CP1_CVT_L   { R4300_OP_CP1_CVT_L,   IDEC_FDL_FS_FMT }
#define CP1_CVT_S   { R4300_OP_CP1_CVT_S,   IDEC_FDS_FS_FMT }
#define CP1_CVT_W   { R4300_OP_CP1_CVT_W,   IDEC_FDW_FS_FMT }
#define CP1_DIV     { R4300_OP_CP1_DIV,     IDEC_FD_FS_FT_FMT }
#define CP1_FLOOR_L { R4300_OP_CP1_FLOOR_L, IDEC_FDL_FS_FMT }
#define CP1_FLOOR_W { R4300_OP_CP1_FLOOR_W, IDEC_FDW_FS_FMT }
#define CP1_MOV     { R4300_OP_CP1_MOV,     IDEC_FD_FS_FMT }
#define CP1_MUL     { R4300_OP_CP1_MUL,     IDEC_FD_FS_FT_FMT }
#define CP1_NEG     { R4300_OP_CP1_NEG,     IDEC_FD_FS_FMT }
#define CP1_ROUND_L { R4300_OP_CP1_ROUND_L, IDEC_FDL_FS_FMT }
#define CP1_ROUND_W { R4300_OP_CP1_ROUND_W, IDEC_FDW_FS_FMT }
#define CP1_SQRT    { R4300_OP_CP1_SQRT,    IDEC_FD_FS_FMT }
#define CP1_SUB     { R4300_OP_CP1_SUB,     IDEC_FD_FS_FT_FMT }
#define CP1_TRUNC_L { R4300_OP_CP1_TRUNC_L, IDEC_FDL_FS_FMT }
#define CP1_TRUNC_W { R4300_OP_CP1_TRUNC_W, IDEC_FDW_FS_FMT }
#define CTC0        { R4300_OP_CTC0,        IDEC_RT_CCR0 }
#define CTC1        { R4300_OP_CTC1,        IDEC_RT_FCR }
#define CTC2        { R4300_OP_CTC2,        IDEC_RT_CCR2 }
#define DADD        { R4300_OP_DADD,        IDEC_RD_RS_RT }
#define DADDI       { R4300_OP_DADDI,       IDEC_RT_RS_SIMM }
#define DADDIU      { R4300_OP_DADDIU,      IDEC_RT_RS_SIMM }
#define DADDU       { R4300_OP_DADDU,       IDEC_RD_RS_RT }
#define DDIV        { R4300_OP_DDIV,        IDEC_RS_RT }
#define DDIVU       { R4300_OP_DDIVU,       IDEC_RS_RT }
#define DIV         { R4300_OP_DIV,         IDEC_RS_RT }
#define DIVU        { R4300_OP_DIVU,        IDEC_RS_RT }
#define DMFC0       { R4300_OP_DMFC0,       IDEC_RT_CPR0 }
#define DMFC1       { R4300_OP_DMFC1,       IDEC_RT_FS64 }
#define DMFC2       { R4300_OP_DMFC2,       IDEC_RT_CPR2 }
#define DMTC0       { R4300_OP_DMTC0,       IDEC_RT_CPR0 }
#define DMTC1       { R4300_OP_DMTC1,       IDEC_RT_FS64 }
#define DMTC2       { R4300_OP_DMTC2,       IDEC_RT_CPR2 }
#define DMULT       { R4300_OP_DMULT,       IDEC_RS_RT }
#define DMULTU      { R4300_OP_DMULTU,      IDEC_RS_RT }
#define DSLL        { R4300_OP_DSLL,        IDEC_RD_RT_SA }
#define DSLLV       { R4300_OP_DSLLV,       IDEC_RD_RT_RS }
#define DSLL32      { R4300_OP_DSLL32,      IDEC_RD_RT_SA }
#define DSRA        { R4300_OP_DSRA,        IDEC_RD_RT_SA }
#define DSRAV       { R4300_OP_DSRAV,       IDEC_RD_RT_RS }
#define DSRA32      { R4300_OP_DSRA32,      IDEC_RD_RT_SA }
#define DSRL        { R4300_OP_DSRL,        IDEC_RD_RT_SA }
#define DSRLV       { R4300_OP_DSRLV,       IDEC_RD_RT_RS }
#define DSRL32      { R4300_OP_DSRL32,      IDEC_RD_RT_SA }
#define DSUB        { R4300_OP_DSUB,        IDEC_RD_RS_RT }
#define DSUBU       { R4300_OP_DSUBU,       IDEC_RD_RS_RT }
#define ERET        { R4300_OP_ERET,        IDEC_NONE }
#define J           { R4300_OP_J,           IDEC_TARGET }
#define JAL         { R4300_OP_JAL,         IDEC_TARGET }
#define JALR        { R4300_OP_JALR,        IDEC_RD_RS }
#define JR          { R4300_OP_JR,          IDEC_RS }
#define LB          { R4300_OP_LB,          IDEC_RT_BASE_OFFSET }
#define LBU         { R4300_OP_LBU,         IDEC_RT_BASE_OFFSET }
#define LD          { R4300_OP_LD,          IDEC_RT_BASE_OFFSET }
#define LDC1        { R4300_OP_LDC1,        IDEC_FT64_BASE_OFFSET }
#define LDC2        { R4300_OP_LDC2,        IDEC_CPR2_BASE_OFFSET }
#define LDL         { R4300_OP_LDL,         IDEC_RT_BASE_OFFSET }
#define LDR         { R4300_OP_LDR,         IDEC_RT_BASE_OFFSET }
#define LH          { R4300_OP_LH,          IDEC_RT_BASE_OFFSET }
#define LHU         { R4300_OP_LHU,         IDEC_RT_BASE_OFFSET }
#define LL          { R4300_OP_LL,          IDEC_RT_BASE_OFFSET }
#define LLD         { R4300_OP_LLD,         IDEC_RT_BASE_OFFSET }
#define LUI         { R4300_OP_LUI,         IDEC_RT_LUI }
#define LW          { R4300_OP_LW,          IDEC_RT_BASE_OFFSET }
#define LWC1        { R4300_OP_LWC1,        IDEC_FT32_BASE_OFFSET }
#define LWC2        { R4300_OP_LWC2,        IDEC_CPR2_BASE_OFFSET }
#define LWL         { R4300_OP_LWL,         IDEC_RT_BASE_OFFSET }
#define LWR         { R4300_OP_LWR,         IDEC_RT_BASE_OFFSET }
#define LWU         { R4300_OP_LWU,         IDEC_RT_BASE_OFFSET }
#define MFC0        { R4300_OP_MFC0,        IDEC_RT_CPR0 }
#define MFC1        { R4300_OP_MFC1,        IDEC_RT_FS32 }
#define MFC2        { R4300_OP_MFC2,        IDEC_RT_CPR2 }
#define MFHI        { R4300_OP_MFHI,        IDEC_RD }
#define MFLO        { R4300_OP_MFLO,        IDEC_RD }
#define MTC0        { R4300_OP_MTC0,        IDEC_RT_CPR0 }
#define MTC1        { R4300_OP_MTC1,        IDEC_RT_FS32 }
#define MTC2        { R4300_OP_MTC2,        IDEC_RT_CPR2 }
#define MTHI        { R4300_OP_MTHI,        IDEC_RS }
#define MTLO        { R4300_OP_MTLO,        IDEC_RS }
#define MULT        { R4300_OP_MULT,        IDEC_RS_RT }
#define MULTU       { R4300_OP_MULTU,       IDEC_RS_RT }
#define NOP         { R4300_OP_NOP,         IDEC_NONE }
#define NOR         { R4300_OP_NOR,         IDEC_RD_RS_RT }
#define OR          { R4300_OP_OR,          IDEC_RD_RS_RT }
#define ORI         { R4300_OP_ORI,         IDEC_RT_RS_ZIMM }
#define SB          { R4300_OP_SB,          IDEC_RT_BASE_OFFSET }
#define SC          { R4300_OP_SC,          IDEC_RT_BASE_OFFSET }
#define SCD         { R4300_OP_SCD,         IDEC_RT_BASE_OFFSET }
#define SD          { R4300_OP_SD,          IDEC_RT_BASE_OFFSET }
#define SDC1        { R4300_OP_SDC1,        IDEC_FT64_BASE_OFFSET }
#define SDC2        { R4300_OP_SDC2,        IDEC_CPR2_BASE_OFFSET }
#define SDL         { R4300_OP_SDL,         IDEC_RT_BASE_OFFSET }
#define SDR         { R4300_OP_SDR,         IDEC_RT_BASE_OFFSET }
#define SH          { R4300_OP_SH,          IDEC_RT_BASE_OFFSET }
#define SLL         { R4300_OP_SLL,         IDEC_RD_RT_SA }
#define SLLV        { R4300_OP_SLLV,        IDEC_RD_RT_RS }
#define SLT         { R4300_OP_SLT,         IDEC_RD_RS_RT }
#define SLTI        { R4300_OP_SLTI,        IDEC_RT_RS_SIMM }
#define SLTIU       { R4300_OP_SLTIU,       IDEC_RT_RS_SIMM }
#define SLTU        { R4300_OP_SLTU,        IDEC_RD_RS_RT }
#define SRA         { R4300_OP_SRA,         IDEC_RD_RT_SA }
#define SRAV        { R4300_OP_SRAV,        IDEC_RD_RT_RS }
#define SRL         { R4300_OP_SRL,         IDEC_RD_RT_SA }
#define SRLV        { R4300_OP_SRLV,        IDEC_RD_RT_RS }
#define SUB         { R4300_OP_SUB,         IDEC_RD_RS_RT }
#define SUBU        { R4300_OP_SUBU,        IDEC_RD_RS_RT }
#define SW          { R4300_OP_SW,          IDEC_RT_BASE_OFFSET }
#define SWC1        { R4300_OP_SWC1,        IDEC_FT32_BASE_OFFSET }
#define SWC2        { R4300_OP_SWC2,        IDEC_CPR2_BASE_OFFSET }
#define SWL         { R4300_OP_SWL,         IDEC_RT_BASE_OFFSET }
#define SWR         { R4300_OP_SWR,         IDEC_RT_BASE_OFFSET }
#define SYNC        { R4300_OP_SYNC,        IDEC_NONE }
#define SYSCALL     { R4300_OP_SYSCALL,     IDEC_NONE }
#define TEQ         { R4300_OP_TEQ,         IDEC_RS_RT }
#define TEQI        { R4300_OP_TEQI,        IDEC_RS_SIMM }
#define TGE         { R4300_OP_TGE,         IDEC_RS_RT }
#define TGEI        { R4300_OP_TGEI,        IDEC_RS_SIMM }
#define TGEIU       { R4300_OP_TGEIU,       IDEC_RS_SIMM }
#define TGEU        { R4300_OP_TGEU,        IDEC_RS_RT }
#define TLBP        { R4300_OP_TLBP,        IDEC_NONE }
#define TLBR        { R4300_OP_TLBR,        IDEC_NONE }
#define TLBWI       { R4300_OP_TLBWI,       IDEC_NONE }
#define TLBWR       { R4300_OP_TLBWR,       IDEC_NONE }
#define TLT         { R4300_OP_TLT,         IDEC_RS_RT }
#define TLTI        { R4300_OP_TLTI,        IDEC_RS_SIMM }
#define TLTIU       { R4300_OP_TLTIU,       IDEC_RS_SIMM }
#define TLTU        { R4300_OP_TLTU,        IDEC_RS_RT }
#define TNE         { R4300_OP_TNE,         IDEC_RS_RT }
#define TNEI        { R4300_OP_TNEI,        IDEC_RS_SIMM }
#define XOR         { R4300_OP_XOR,         IDEC_RD_RS_RT }
#define XORI        { R4300_OP_XORI,        IDEC_RT_RS_ZIMM }

#define SPECIAL     RESERVED
#define REGIMM      RESERVED
#define COP0        RESERVED
#define COP1        RESERVED
#define COP2        RESERVED


static const struct r4300_idec r4300_op_table[] = {
/* Main opcodes table
 * 0-63
 */
    SPECIAL,     REGIMM,      J,           JAL,
    BEQ,         BNE,         BLEZ,        BGTZ,
    ADDI,        ADDIU,       SLTI,        SLTIU,
    ANDI,        ORI,         XORI,        LUI,
    COP0,        COP1,        COP2,        RESERVED,
    BEQL,        BNEL,        BLEZL,       BGTZL,
    DADDI,       DADDIU,      LDL,         LDR,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    LB,          LH,          LWL,         LW,
    LBU,         LHU,         LWR,         LWU,
    SB,          SH,          SWL,         SW,
    SDL,         SDR,         SWR,         CACHE,
    LL,          LWC1,        LWC2,        RESERVED,
    LLD,         LDC1,        LDC2,        LD,
    SC,          SWC1,        SWC2,        RESERVED,
    SCD,         SDC1,        SDC2,        SD,
/* SPECIAL opcodes table
 * 64-127
 */
    SLL,         RESERVED,    SRL,         SRA,
    SLLV,        RESERVED,    SRLV,        SRAV,
    JR,          JALR,        RESERVED,    RESERVED,
    SYSCALL,     BREAK,       RESERVED,    SYNC,
    MFHI,        MTHI,        MFLO,        MTLO,
    DSLLV,       RESERVED,    DSRLV,       DSRAV,
    MULT,        MULTU,       DIV,         DIVU,
    DMULT,       DMULTU,      DDIV,        DDIVU,
    ADD,         ADDU,        SUB,         SUBU,
    AND,         OR,          XOR,         NOR,
    RESERVED,    RESERVED,    SLT,         SLTU,
    DADD,        DADDU,       DSUB,        DSUBU,
    TGE,         TGEU,        TLT,         TLTU,
    TEQ,         RESERVED,    TNE,         RESERVED,
    DSLL,        RESERVED,    DSRL,        DSRA,
    DSLL32,      RESERVED,    DSRL32,      DSRA32,
/* REGIMM opcodes table
 * 128-159
 */
    BLTZ,        BGEZ,        BLTZL,       BGEZL,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    TGEI,        TGEIU,       TLTI,        TLTIU,
    TEQI,        RESERVED,    TNEI,        RESERVED,
    BLTZAL,      BGEZAL,      BLTZALL,     BGEZALL,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
/* COP0 opcodes table
 * 160-167
 */
    MFC0,        DMFC0,       CFC0,        RESERVED,
    MTC0,        DMTC0,       CTC0,        RESERVED,
/* BC0 opcodes table
 * 168-175
 */
    BC0F,        BC0T,        BC0FL,       BC0TL,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
/* TLB opcodes table
 * 176-239
 */
    RESERVED,    TLBR,        TLBWI,       RESERVED,
    RESERVED,    RESERVED,    TLBWR,       RESERVED,
    TLBP,        RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    ERET,        RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
/* COP1 opcodes table
 * 240-247
 */
    MFC1,        DMFC1,       CFC1,        RESERVED,
    MTC1,        DMTC1,       CTC1,        RESERVED,
/* BC1 opcodes table
 * 248-255
 */
    BC1F,        BC1T,        BC1FL,       BC1TL,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
/* FPU opcodes table
 * 256-319
 */
    CP1_ADD,     CP1_SUB,     CP1_MUL,     CP1_DIV,
    CP1_SQRT,    CP1_ABS,     CP1_MOV,     CP1_NEG,
    CP1_ROUND_L, CP1_TRUNC_L, CP1_CEIL_L,  CP1_FLOOR_L,
    CP1_ROUND_W, CP1_TRUNC_W, CP1_CEIL_W,  CP1_FLOOR_W,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    CP1_CVT_S,   CP1_CVT_D,   RESERVED,    RESERVED,
    CP1_CVT_W,   CP1_CVT_L,   RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
    CP1_C_F,     CP1_C_UN,    CP1_C_EQ,    CP1_C_UEQ,
    CP1_C_OLT,   CP1_C_ULT,   CP1_C_OLE,   CP1_C_ULE,
    CP1_C_SF,    CP1_C_NGLE,  CP1_C_SEQ,   CP1_C_NGL,
    CP1_C_LT,    CP1_C_NGE,   CP1_C_LE,    CP1_C_NGT,
/* COP2 opcodes table
 * 320-327
 */
    MFC2,        DMFC2,       CFC2,        RESERVED,
    MTC2,        DMTC2,       CTC2,        RESERVED,
/* BC2 opcodes table
 * 328-335
 */
    BC2F,        BC2T,        BC2FL,       BC2TL,
    RESERVED,    RESERVED,    RESERVED,    RESERVED,
/* Pseudo opcodes
 * 336
 */
	NOP
};

#define E_INV       {   0,  0, 0x00 }
#define E_MAIN      {   0, 26, 0x3f }
#define E_SPECIAL   {  64,  0, 0x3f }
#define E_REGIMM    { 128, 16, 0x1f }

#define E_COP0      { 160, 21, 0x07 }
#define E_BC0       { 168, 16, 0x07 }
#define E_TLB       { 176,  0, 0x3f }

#define E_COP1      { 240, 21, 0x07 }
#define E_BC1       { 248, 16, 0x07 }
#define E_FPU       { 256,  0, 0x3f }

#define E_COP2      { 320, 21, 0x07 }
#define E_BC2       { 328, 16, 0x07 }

struct r4300_op_escape {
	uint16_t offset;
	uint8_t shift;
	uint8_t mask;
};


static const struct r4300_op_escape r4300_escapes_table[] = {

    /* 000000 - special */
	E_SPECIAL, E_SPECIAL, E_SPECIAL, E_SPECIAL,

    /* 000001 - regimm */
    E_REGIMM,  E_REGIMM,  E_REGIMM,  E_REGIMM,

    /* 000010,001111 - main */
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,

    /* 010000 - cop0 */
    E_COP0,    E_BC0,     E_TLB,     E_TLB,
    /* 010001 - cop1 */
    E_COP1,    E_BC1,     E_FPU,     E_FPU,
    /* 010010 - cop2 */
    E_COP2,    E_BC2,     E_INV,     E_INV,

    /* 010011,111111 - main */
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
    E_MAIN,    E_MAIN,    E_MAIN,    E_MAIN,
};


const struct r4300_idec* r4300_get_idec(uint32_t iw) {
	const struct r4300_op_escape* escape;

	/* handle NOP pseudo instruction */
	if (iw == 0) {
		return &r4300_op_table[336];
	}

	escape = &r4300_escapes_table[(iw >> 24)];
	return &r4300_op_table[escape->offset + ((iw >> escape->shift) & escape->mask)];
}

size_t idec_u53(uint32_t iw, uint8_t u53, uint8_t* u5)
{
    size_t o = 0;
    uint8_t r = (iw >> U53_SHIFT(u53)) & 0x1f;

    switch (U53_TYPE(u53))
    {
    case IDEC_REGTYPE_NONE:
        o = 0;
        break;
    case IDEC_REGTYPE_GPR:
        o = R4300_REGS_OFFSET + r * sizeof(int64_t);
        break;
    case IDEC_REGTYPE_CPR0:
        o = R4300_CP0_REGS_OFFSET + r * sizeof(uint32_t);
        break;
    case IDEC_REGTYPE_FPR32:
        o = R4300_CP1_REGS_S_OFFSET + r * sizeof(float*);
        break;
    case IDEC_REGTYPE_FPR64:
        o = R4300_CP1_REGS_D_OFFSET + r * sizeof(double*);
        break;
    case IDEC_REGTYPE_FPR:
        switch((iw >> U53_SHIFT(U53_FMT) & 0x1f))
        {
        case 16: /* S */
        case 20: /* W */
            o = R4300_CP1_REGS_S_OFFSET + r * sizeof(float*);
            break;
        case 17: /* D */
        case 21: /* L */
            o = R4300_CP1_REGS_D_OFFSET + r * sizeof(double*);
            break;
        default: /* reserved instruction - (ex: LEGO)*/ break;
        }
        break;
    case IDEC_REGTYPE_FCR:
        o = (r == 0)
            ? R4300_CP1_FCR0_OFFSET
            : R4300_CP1_FCR31_OFFSET;
        break;

    default: assert(0);
    }

    *u5 = r;
    return o;
}

#define X(op) #op
const char* g_r4300_opcodes[R4300_OPCODES_COUNT] =
{
#include "opcodes.md"
};
#undef X
