/******************************************************************************\
* Project:  MSP Simulation Layer for Scalar Unit Operations                    *
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

#include "su.h"

/*
 * including modular interface structure to access configuration settings...
 * Some of the parallel timing features require perfect timing or configs.
 */
#include "module.h"

u32 inst_word;

u32 SR[32];
typedef VECTOR_OPERATION(*p_vector_func)(v16, v16);

pu8 DRAM;
pu8 DMEM;
pu8 IMEM;

NOINLINE void res_S(void)
{
    message("RESERVED.");
    return;
}

void set_PC(unsigned int address)
{
    temp_PC = 0x04001000 + FIT_IMEM(address);
#ifndef EMULATE_STATIC_PC
    stage = 1;
#endif
    return;
}

pu32 CR[NUMBER_OF_CP0_REGISTERS];
u8 conf[32];

int MF_SP_STATUS_TIMEOUT;

void SP_CP0_MF(unsigned int rt, unsigned int rd)
{
    SR[rt] = *(CR[rd %= NUMBER_OF_CP0_REGISTERS]);
    SR[zero] = 0x00000000;
    if (rd == 0x7) {
        if (CFG_MEND_SEMAPHORE_LOCK == 0)
            return;
        if (CFG_HLE_GFX | CFG_HLE_AUD)
            return;
        GET_RCP_REG(SP_SEMAPHORE_REG) = 0x00000001;
        GET_RCP_REG(SP_STATUS_REG) |= SP_STATUS_HALT; /* temporary hack */
        return;
    }
#ifdef WAIT_FOR_CPU_HOST
    if (rd == 0x4) {
        MFC0_count[rt] += 1;
        GET_RCP_REG(SP_STATUS_REG) |= (MFC0_count[rt] >= MF_SP_STATUS_TIMEOUT);
    }
#endif
    return;
}

static void MT_DMA_CACHE(unsigned int rt)
{
    *CR[0x0] = SR[rt] & 0xFFFFFFF8ul; /* & 0x00001FF8 */
    return; /* Reserved upper bits are ignored during DMA R/W. */
}
static void MT_DMA_DRAM(unsigned int rt)
{
    *CR[0x1] = SR[rt] & 0xFFFFFFF8ul; /* & 0x00FFFFF8 */
    return; /* Let the reserved bits get sent, but the pointer is 24-bit. */
}
static void MT_DMA_READ_LENGTH(unsigned int rt)
{
    *CR[0x2] = SR[rt] | 07;
    SP_DMA_READ();
    return;
}
static void MT_DMA_WRITE_LENGTH(unsigned int rt)
{
    *CR[0x3] = SR[rt] | 07;
    SP_DMA_WRITE();
    return;
}
static void MT_SP_STATUS(unsigned int rt)
{
    pu32 MI_INTR_REG;
    pu32 SP_STATUS_REG;

    if (SR[rt] & 0xFE000040)
        message("MTC0\nSP_STATUS");
    MI_INTR_REG = GET_RSP_INFO(MI_INTR_REG);
    SP_STATUS_REG = GET_RSP_INFO(SP_STATUS_REG);

    *SP_STATUS_REG &= ~(!!(SR[rt] & 0x00000001) <<  0);
    *SP_STATUS_REG |=  (!!(SR[rt] & 0x00000002) <<  0);
    *SP_STATUS_REG &= ~(!!(SR[rt] & 0x00000004) <<  1);
    *MI_INTR_REG &= ~((SR[rt] & 0x00000008) >> 3); /* SP_CLR_INTR */
    *MI_INTR_REG |=  ((SR[rt] & 0x00000010) >> 4); /* SP_SET_INTR */
    *SP_STATUS_REG |= (SR[rt] & 0x00000010) >> 4; /* int set halt */
    *SP_STATUS_REG &= ~(!!(SR[rt] & 0x00000020) <<  5);
 /* *SP_STATUS_REG |=  (!!(SR[rt] & 0x00000040) <<  5); */
    *SP_STATUS_REG &= ~(!!(SR[rt] & 0x00000080) <<  6);
    *SP_STATUS_REG |=  (!!(SR[rt] & 0x00000100) <<  6);
    *SP_STATUS_REG &= ~(!!(SR[rt] & 0x00000200) <<  7);
    *SP_STATUS_REG |=  (!!(SR[rt] & 0x00000400) <<  7); /* yield request? */
    *SP_STATUS_REG &= ~(!!(SR[rt] & 0x00000800) <<  8);
    *SP_STATUS_REG |=  (!!(SR[rt] & 0x00001000) <<  8); /* yielded? */
    *SP_STATUS_REG &= ~(!!(SR[rt] & 0x00002000) <<  9);
    *SP_STATUS_REG |=  (!!(SR[rt] & 0x00004000) <<  9); /* task done? */
    *SP_STATUS_REG &= ~(!!(SR[rt] & 0x00008000) << 10);
    *SP_STATUS_REG |=  (!!(SR[rt] & 0x00010000) << 10);
    *SP_STATUS_REG &= ~(!!(SR[rt] & 0x00020000) << 11);
    *SP_STATUS_REG |=  (!!(SR[rt] & 0x00040000) << 11);
    *SP_STATUS_REG &= ~(!!(SR[rt] & 0x00080000) << 12);
    *SP_STATUS_REG |=  (!!(SR[rt] & 0x00100000) << 12);
    *SP_STATUS_REG &= ~(!!(SR[rt] & 0x00200000) << 13);
    *SP_STATUS_REG |=  (!!(SR[rt] & 0x00400000) << 13);
    *SP_STATUS_REG &= ~(!!(SR[rt] & 0x00800000) << 14);
    *SP_STATUS_REG |=  (!!(SR[rt] & 0x01000000) << 14);
    return;
}
static void MT_SP_RESERVED(unsigned int rt)
{
    const u32 source = SR[rt] & 0x00000000ul; /* forced (zilmar, dox) */

    GET_RCP_REG(SP_SEMAPHORE_REG) = source;
    return;
}
static void MT_CMD_START(unsigned int rt)
{
    const u32 source = SR[rt] & 0xFFFFFFF8ul; /* Funnelcube demo by marshallh */

    if (GET_RCP_REG(DPC_BUFBUSY_REG)) /* lock hazards not implemented */
        message("MTC0\nCMD_START");
    GET_RCP_REG(DPC_END_REG)
  = GET_RCP_REG(DPC_CURRENT_REG)
  = GET_RCP_REG(DPC_START_REG)
  = source;
    return;
}
static void MT_CMD_END(unsigned int rt)
{
    if (GET_RCP_REG(DPC_BUFBUSY_REG))
        message("MTC0\nCMD_END"); /* This is just CA-related. */
    GET_RCP_REG(DPC_END_REG) = SR[rt] & 0xFFFFFFF8ul;
    GBI_phase();
    return;
}
static void MT_CMD_STATUS(unsigned int rt)
{
    pu32 DPC_STATUS_REG;

    if (SR[rt] & 0xFFFFFD80ul) /* unsupported or reserved bits */
        message("MTC0\nCMD_STATUS");
    DPC_STATUS_REG = GET_RSP_INFO(DPC_STATUS_REG);

    *DPC_STATUS_REG &= ~(!!(SR[rt] & 0x00000001) << 0);
    *DPC_STATUS_REG |=  (!!(SR[rt] & 0x00000002) << 0);
    *DPC_STATUS_REG &= ~(!!(SR[rt] & 0x00000004) << 1);
    *DPC_STATUS_REG |=  (!!(SR[rt] & 0x00000008) << 1);
    *DPC_STATUS_REG &= ~(!!(SR[rt] & 0x00000010) << 2);
    *DPC_STATUS_REG |=  (!!(SR[rt] & 0x00000020) << 2);
/* Some NUS-CIC-6105 SP tasks try to clear some DPC cycle timers. */
    GET_RCP_REG(DPC_TMEM_REG)     &= !(SR[rt] & 0x00000040) ? ~0u : 0u;
 /* GET_RCP_REG(DPC_PIPEBUSY_REG) &= !(SR[rt] & 0x00000080) ? ~0u : 0u; */
 /* GET_RCP_REG(DPC_BUFBUSY_REG)  &= !(SR[rt] & 0x00000100) ? ~0u : 0u; */
    GET_RCP_REG(DPC_CLOCK_REG)    &= !(SR[rt] & 0x00000200) ? ~0u : 0u;
    return;
}
static void MT_CMD_CLOCK(unsigned int rt)
{
    message("MTC0\nCMD_CLOCK"); /* read-only?? */
    GET_RCP_REG(DPC_CLOCK_REG) = SR[rt];
    return; /* Appendix says this is RW; elsewhere it says R. */
}
static void MT_READ_ONLY(unsigned int rt)
{
    static char write_to_read_only[] = "Invalid MTC0 from SR[00].";

    write_to_read_only[21] = '0' + (unsigned char)rt/10;
    write_to_read_only[22] = '0' + (unsigned char)rt%10;
    message(write_to_read_only);
    return;
}

static void (*SP_CP0_MT[NUMBER_OF_CP0_REGISTERS])(unsigned int) = {
MT_DMA_CACHE       ,MT_DMA_DRAM        ,MT_DMA_READ_LENGTH ,MT_DMA_WRITE_LENGTH,
MT_SP_STATUS       ,MT_READ_ONLY       ,MT_READ_ONLY       ,MT_SP_RESERVED,
MT_CMD_START       ,MT_CMD_END         ,MT_READ_ONLY       ,MT_CMD_STATUS,
MT_CMD_CLOCK       ,MT_READ_ONLY       ,MT_READ_ONLY       ,MT_READ_ONLY
};

void SP_DMA_READ(void)
{
    unsigned int offC, offD; /* SP cache and dynamic DMA pointers */
    register unsigned int length;
    register unsigned int count;
    register unsigned int skip;

    length = (GET_RCP_REG(SP_RD_LEN_REG) & 0x00000FFFul) >>  0;
    count  = (GET_RCP_REG(SP_RD_LEN_REG) & 0x000FF000ul) >> 12;
    skip   = (GET_RCP_REG(SP_RD_LEN_REG) & 0xFFF00000ul) >> 20;
#ifdef _DEBUG
    length |= 07; /* already corrected by mtc0 */
#endif
    ++length;
    ++count;
    skip += length;
    do {
        register unsigned int i;

        i = 0;
        --count;
        do {
            offC = (count*length + *CR[0x0] + i) & 0x00001FF8ul;
            offD = (count*skip + *CR[0x1] + i) & 0x00FFFFF8ul;
            *(pi64)(DMEM + offC) =
                *(pi64)(DRAM + offD)
              & (offD & ~MAX_DRAM_DMA_ADDR ? 0 : ~0) /* 0 if (addr > limit) */
            ;
            i += 0x008;
        } while (i < length);
    } while (count);

    if ((*CR[0x0] & 0x1000) ^ (offC & 0x1000))
        message("DMA over the DMEM-to-IMEM gap.");
    GET_RCP_REG(SP_DMA_BUSY_REG)  =  0x00000000;
    GET_RCP_REG(SP_STATUS_REG)   &= ~SP_STATUS_DMA_BUSY;
    return;
}
void SP_DMA_WRITE(void)
{
    unsigned int offC, offD; /* SP cache and dynamic DMA pointers */
    register unsigned int length;
    register unsigned int count;
    register unsigned int skip;

    length = (GET_RCP_REG(SP_WR_LEN_REG) & 0x00000FFFul) >>  0;
    count  = (GET_RCP_REG(SP_WR_LEN_REG) & 0x000FF000ul) >> 12;
    skip   = (GET_RCP_REG(SP_WR_LEN_REG) & 0xFFF00000ul) >> 20;

#ifdef _DEBUG
    length |= 07; /* already corrected by mtc0 */
#endif
    ++length;
    ++count;
    skip += length;
    do {
        register unsigned int i;

        i = 0;
        --count;
        do {
            offC = (count*length + *CR[0x0] + i) & 0x00001FF8ul;
            offD = (count*skip + *CR[0x1] + i) & 0x00FFFFF8ul;
            *(pi64)(DRAM + offD) = *(pi64)(DMEM + offC);
            i += 0x000008;
        } while (i < length);
    } while (count);

    if ((*CR[0x0] & 0x1000) ^ (offC & 0x1000))
        message("DMA over the DMEM-to-IMEM gap.");
    GET_RCP_REG(SP_DMA_BUSY_REG)  =  0x00000000;
    GET_RCP_REG(SP_STATUS_REG)   &= ~SP_STATUS_DMA_BUSY;
    return;
}

/*** scalar, R4000 control flow manipulation ***/

PROFILE_MODE void J(u32 inst)
{
    set_PC(4 * inst);
}
PROFILE_MODE void JAL(u32 inst, u32 PC)
{
    SR[ra] = FIT_IMEM(PC + LINK_OFF);
    set_PC(4 * inst);
}

PROFILE_MODE int BEQ(u32 inst, u32 PC)
{
    const unsigned int rs = (inst >> 21) % (1 << 5);
    const unsigned int rt = (inst >> 16) % (1 << 5);

    if (!(SR[rs] == SR[rt]))
        return 0;
    set_PC(PC + 4*inst + SLOT_OFF);
    return 1;
}
PROFILE_MODE int BNE(u32 inst, u32 PC)
{
    const unsigned int rs = (inst >> 21) % (1 << 5);
    const unsigned int rt = (inst >> 16) % (1 << 5);

    if (!(SR[rs] != SR[rt]))
        return 0;
    set_PC(PC + 4*inst + SLOT_OFF);
    return 1;
}
PROFILE_MODE int BLEZ(u32 inst, u32 PC)
{
    const unsigned int rs = (inst >> 21) % (1 << 5);

    if (!((s32)SR[rs] <= 0))
        return 0;
    set_PC(PC + 4*inst + SLOT_OFF);
    return 1;
}
PROFILE_MODE int BGTZ(u32 inst, u32 PC)
{
    const unsigned int rs = (inst >> 21) % (1 << 5);

    if (!((s32)SR[rs] >  0))
        return 0;
    set_PC(PC + 4*inst + SLOT_OFF);
    return 1;
}

/*** scalar, R4000 bit-wise logical operations ***/

PROFILE_MODE void ANDI(u32 inst)
{
    const u16 immediate = (u16)(inst & 0x0000FFFFu);
    const unsigned int rs = (inst >> 21) % (1 << 5);
    const unsigned int rt = (inst >> 16) % (1 << 5);

    SR[rt] = SR[rs] & immediate;
    SR[zero] = 0x00000000;
}
PROFILE_MODE void ORI(u32 inst)
{
    const u16 immediate = (u16)(inst & 0x0000FFFFu);
    const unsigned int rs = (inst >> 21) % (1 << 5);
    const unsigned int rt = (inst >> 16) % (1 << 5);

    SR[rt] = SR[rs] | immediate;
    SR[zero] = 0x00000000;
}
PROFILE_MODE void XORI(u32 inst)
{
    const u16 immediate = (u16)(inst & 0x0000FFFFu);
    const unsigned int rs = (inst >> 21) % (1 << 5);
    const unsigned int rt = (inst >> 16) % (1 << 5);

    SR[rt] = SR[rs] ^ immediate;
    SR[zero] = 0x00000000;
}
PROFILE_MODE void LUI(u32 inst)
{
    const u16 immediate = (u16)(inst & 0x0000FFFFu);
    const unsigned int rt = (inst >> 16) % (1 << 5);

    SR[rt] = (u32)immediate << 16; /* or:  SR[rt] = 0; SR[rt]31..16 = imm; */
    SR[zero] = 0x00000000;
}

/*** scalar, R4000 arithmetic operations ***/

PROFILE_MODE void ADDIU(u32 inst)
{
    const u16 immediate = (u16)(inst & 0x0000FFFFu);
    const unsigned int rs = (inst >> 21) % (1 << 5);
    const unsigned int rt = (inst >> 16) % (1 << 5);

    SR[rt] = SR[rs] + (s16)(immediate);
    SR[zero] = 0x00000000;
}
PROFILE_MODE void SLTI(u32 inst)
{
    const u16 immediate = (u16)(inst & 0x0000FFFFu);
    const unsigned int rs = (inst >> 21) % (1 << 5);
    const unsigned int rt = (inst >> 16) % (1 << 5);

    SR[rt] = ((s32)(SR[rs]) < (s32)SIGNED_IMM16(immediate)) ? 1 : 0;
    SR[zero] = 0x00000000;
}
PROFILE_MODE void SLTIU(u32 inst)
{
    const u16 immediate = (u16)(inst & 0x0000FFFFu);
    const unsigned int rs = (inst >> 21) % (1 << 5);
    const unsigned int rt = (inst >> 16) % (1 << 5);

    SR[rt] = ((u32)(SR[rs]) < (u32)SIGNED_IMM16(immediate)) ? 1 : 0;
    SR[zero] = 0x00000000;
}

/*** scalar, R4000 memory loads and stores ***/

PROFILE_MODE void LB(u32 inst)
{
    u32 addr;
    const s16 offset = (s16)(inst & 0x0000FFFFul);
    const unsigned int base = (inst >> 21) % (1 << 5);
    const unsigned int rt   = (inst >> 16) % (1 << 5);

    addr = SR[base] + offset;
    SR[rt] = DMEM[BES(addr) & 0x00000FFFul];
    SR[rt] = (s8)SR[rt];
    SR[zero] = 0x00000000;
}
PROFILE_MODE void LH(u32 inst)
{
    u32 addr;
    const s16 offset = (s16)(inst & 0x0000FFFFul);
    const unsigned int base = (inst >> 21) % (1 << 5);
    const unsigned int rt   = (inst >> 16) % (1 << 5);

    addr = SR[base] + offset;
    SR[rt] = 0x00000000
      | DMEM[BES(addr + 0) & 0x00000FFFul] <<  8
      | DMEM[BES(addr + 1) & 0x00000FFFul] <<  0
    ;
    SR[rt] = (s16)SR[rt];
    SR[zero] = 0x00000000;
}
PROFILE_MODE void LW(u32 inst)
{
    u32 addr;
    const s16 offset = (s16)(inst & 0x0000FFFFul);
    const unsigned int base = (inst >> 21) % (1 << 5);
    const unsigned int rt   = (inst >> 16) % (1 << 5);

    addr = SR[base] + offset;
    SR_B(rt, 0) = DMEM[BES(addr + 0) & 0x00000FFFul];
    SR_B(rt, 1) = DMEM[BES(addr + 1) & 0x00000FFFul];
    SR_B(rt, 2) = DMEM[BES(addr + 2) & 0x00000FFFul];
    SR_B(rt, 3) = DMEM[BES(addr + 3) & 0x00000FFFul];
    SR[zero] = 0x00000000;
}
PROFILE_MODE void LBU(u32 inst)
{
    u32 addr;
    const s16 offset = (s16)(inst & 0x0000FFFFul);
    const unsigned int base = (inst >> 21) % (1 << 5);
    const unsigned int rt   = (inst >> 16) % (1 << 5);

    addr = SR[base] + offset;
    SR[rt] = DMEM[BES(addr) & 0x00000FFFul];
    SR[zero] = 0x00000000;
}
PROFILE_MODE void LHU(u32 inst)
{
    u32 addr;
    const s16 offset = (s16)(inst & 0x0000FFFFul);
    const unsigned int base = (inst >> 21) % (1 << 5);
    const unsigned int rt   = (inst >> 16) % (1 << 5);

    addr = SR[base] + offset;
    SR[rt] = 0x00000000
      | DMEM[BES(addr + 0) & 0x00000FFFul] <<  8
      | DMEM[BES(addr + 1) & 0x00000FFFul] <<  0
    ;
    SR[zero] = 0x00000000;
}

PROFILE_MODE void SB(u32 inst)
{
    u32 addr;
    const s16 offset = (s16)(inst & 0x0000FFFFul);
    const unsigned int base = (inst >> 21) % (1 << 5);
    const unsigned int rt   = (inst >> 16) % (1 << 5);

    addr = SR[base] + offset;
    DMEM[BES(addr) & 0x00000FFFul] = (u8)(SR[rt] & 0xFFu);
}
PROFILE_MODE void SH(u32 inst)
{
    u32 addr;
    const s16 offset = (s16)(inst & 0x0000FFFFul);
    const unsigned int base = (inst >> 21) % (1 << 5);
    const unsigned int rt   = (inst >> 16) % (1 << 5);

    addr = SR[base] + offset;
    DMEM[BES(addr + 0) & 0x00000FFFul] = SR_B(rt, 2);
    DMEM[BES(addr + 1) & 0x00000FFFul] = SR_B(rt, 3);
}
PROFILE_MODE void SW(u32 inst)
{
    u32 addr;
    const s16 offset = (s16)(inst & 0x0000FFFFul);
    const unsigned int base = (inst >> 21) % (1 << 5);
    const unsigned int rt   = (inst >> 16) % (1 << 5);

    addr = SR[base] + offset;
    DMEM[BES(addr + 0) & 0x00000FFFul] = SR_B(rt, 0);
    DMEM[BES(addr + 1) & 0x00000FFFul] = SR_B(rt, 1);
    DMEM[BES(addr + 2) & 0x00000FFFul] = SR_B(rt, 2);
    DMEM[BES(addr + 3) & 0x00000FFFul] = SR_B(rt, 3);
}

/*** scalar, coprocessor operations (vector unit) ***/

u16 rwR_VCE(void)
{ /* never saw a game try to read VCE out to a scalar GPR yet */
    register u16 ret_slot;

    ret_slot = 0x00 | (u16)get_VCE();
    return (ret_slot);
}
void rwW_VCE(u16 vce)
{ /* never saw a game try to write VCE using a scalar GPR yet */
    register int i;

    vce = 0x00 | (vce & 0xFF);
    for (i = 0; i < 8; i++)
        cf_vce[i] = (vce >> i) & 1;
    return;
}

static u16 (*R_VCF[4])(void) = {
    get_VCO,get_VCC,rwR_VCE,rwR_VCE,
};
static void (*W_VCF[4])(u16) = {
    set_VCO,set_VCC,rwW_VCE,rwW_VCE,
};
void MFC2(unsigned int rt, unsigned int vs, unsigned int e)
{
    SR_B(rt, 2) = VR_B(vs, e);
    e = (e + 0x1) & 0xF;
    SR_B(rt, 3) = VR_B(vs, e);
    SR[rt] = (s16)(SR[rt]);
    SR[zero] = 0x00000000;
    return;
}
void MTC2(unsigned int rt, unsigned int vd, unsigned int e)
{
    VR_B(vd, e+0x0) = SR_B(rt, 2);
    VR_B(vd, e+0x1) = SR_B(rt, 3);
    return; /* If element == 0xF, it does not matter; loads do not wrap over. */
}
void CFC2(unsigned int rt, unsigned int rd)
{
    SR[rt] = (s16)R_VCF[rd & 3]();
    SR[zero] = 0x00000000;
    return;
}
void CTC2(unsigned int rt, unsigned int rd)
{
    W_VCF[rd & 3](SR[rt] & 0x0000FFFF);
    return;
}

/*** scalar, coprocessor operations (vector unit, scalar cache transfers) ***/

void LBV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    const unsigned int e = element;

    addr = (SR[base] + 1*offset) & 0x00000FFF;
    VR_B(vt, e) = DMEM[BES(addr)];
    return;
}
void LSV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    signed int correction;
    register u32 addr;
    const unsigned int e = element;

    if (e & 0x1) {
        message("LSV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 2*offset) & 0x00000FFF;
    correction = (signed)(addr % 0x004);
    if (correction == 0x003) {
        message("LSV\nWeird addr.");
        return;
    }
    correction = (correction - 1) * HES(0x000);
    VR_S(vt, e) = *(pi16)(DMEM + addr - correction);
    return;
}
void LLV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    signed int correction;
    register u32 addr;
    const unsigned int e = element;

    if (e & 0x1) {
        message("LLV\nOdd element.");
        return;
    } /* Illegal (but still even) elements are used by Boss Game Studios. */
    addr = (SR[base] + 4*offset) & 0x00000FFF;
    if (addr & 0x00000001) {
        VR_A(vt, e+0x0) = DMEM[BES(addr)];
        addr = (addr + 0x00000001) & 0x00000FFF;
        VR_U(vt, e+0x1) = DMEM[BES(addr)];
        addr = (addr + 0x00000001) & 0x00000FFF;
        VR_A(vt, e+0x2) = DMEM[BES(addr)];
        addr = (addr + 0x00000001) & 0x00000FFF;
        VR_U(vt, e+0x3) = DMEM[BES(addr)];
        return;
    } /* branch very unlikely:  "Star Wars:  Battle for Naboo" unaligned addr */
    correction = HES(0x000)*(addr%0x004 - 1);
    VR_S(vt, e+0x0) = *(pi16)(DMEM + addr - correction);
    addr = (addr + 0x00000002) & 0x00000FFF; /* F3DLX 1.23:  addr%4 is 0x002. */
    VR_S(vt, e+0x2) = *(pi16)(DMEM + addr + correction);
    return;
}
void LDV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    const unsigned int e = element;

    if (e & 0x1) {
        message("LDV\nOdd element.");
        return;
    } /* Illegal (but still even) elements are used by Boss Game Studios. */
    addr = (SR[base] + 8*offset) & 0x00000FFF;

    switch (addr & 07) {
    case 00:
        VR_S(vt, e+0x0) = *(pi16)(DMEM + addr + HES(0x000));
        VR_S(vt, e+0x2) = *(pi16)(DMEM + addr + HES(0x002));
        VR_S(vt, e+0x4) = *(pi16)(DMEM + addr + HES(0x004));
        VR_S(vt, e+0x6) = *(pi16)(DMEM + addr + HES(0x006));
        break;
    case 01: /* standard ABI ucodes (unlike e.g. MusyX w/ even addresses) */
        VR_S(vt, e+0x0) = *(pi16)(DMEM + addr + 0x000);
        VR_A(vt, e+0x2) = DMEM[addr + 0x002 - BES(0x000)];
        VR_U(vt, e+0x3) = DMEM[addr + 0x003 + BES(0x000)];
        VR_S(vt, e+0x4) = *(pi16)(DMEM + addr + 0x004);
        VR_A(vt, e+0x6) = DMEM[addr + 0x006 - BES(0x000)];
        addr += 0x007 + BES(00);
        addr &= 0x00000FFF;
        VR_U(vt, e+0x7) = DMEM[addr];
        break;
    case 02:
        VR_S(vt, e+0x0) = *(pi16)(DMEM + addr + 0x000 - HES(0x000));
        VR_S(vt, e+0x2) = *(pi16)(DMEM + addr + 0x002 + HES(0x000));
        VR_S(vt, e+0x4) = *(pi16)(DMEM + addr + 0x004 - HES(0x000));
        addr += 0x006 + HES(00);
        addr &= 0x00000FFF;
        VR_S(vt, e+0x6) = *(pi16)(DMEM + addr);
        break;
    case 03: /* standard ABI ucodes (unlike e.g. MusyX w/ even addresses) */
        VR_A(vt, e+0x0) = DMEM[addr + 0x000 - BES(0x000)];
        VR_U(vt, e+0x1) = DMEM[addr + 0x001 + BES(0x000)];
        VR_S(vt, e+0x2) = *(pi16)(DMEM + addr + 0x002);
        VR_A(vt, e+0x4) = DMEM[addr + 0x004 - BES(0x000)];
        addr += 0x005 + BES(00);
        addr &= 0x00000FFF;
        VR_U(vt, e+0x5) = DMEM[addr];
        VR_S(vt, e+0x6) = *(pi16)(DMEM + addr + 0x001 - BES(0x000));
        break;
    case 04:
        VR_S(vt, e+0x0) = *(pi16)(DMEM + addr + HES(0x000));
        VR_S(vt, e+0x2) = *(pi16)(DMEM + addr + HES(0x002));
        addr += 0x004 + WES(00);
        addr &= 0x00000FFF;
        VR_S(vt, e+0x4) = *(pi16)(DMEM + addr + HES(0x000));
        VR_S(vt, e+0x6) = *(pi16)(DMEM + addr + HES(0x002));
        break;
    case 05: /* standard ABI ucodes (unlike e.g. MusyX w/ even addresses) */
        VR_S(vt, e+0x0) = *(pi16)(DMEM + addr + 0x000);
        VR_A(vt, e+0x2) = DMEM[addr + 0x002 - BES(0x000)];
        addr += 0x003;
        addr &= 0x00000FFF;
        VR_U(vt, e+0x3) = DMEM[addr + BES(0x000)];
        VR_S(vt, e+0x4) = *(pi16)(DMEM + addr + 0x001);
        VR_A(vt, e+0x6) = DMEM[addr + BES(0x003)];
        VR_U(vt, e+0x7) = DMEM[addr + BES(0x004)];
        break;
    case 06:
        VR_S(vt, e+0x0) = *(pi16)(DMEM + addr - HES(0x000));
        addr += 0x002;
        addr &= 0x00000FFF;
        VR_S(vt, e+0x2) = *(pi16)(DMEM + addr + HES(0x000));
        VR_S(vt, e+0x4) = *(pi16)(DMEM + addr + HES(0x002));
        VR_S(vt, e+0x6) = *(pi16)(DMEM + addr + HES(0x004));
        break;
    case 07: /* standard ABI ucodes (unlike e.g. MusyX w/ even addresses) */
        VR_A(vt, e+0x0) = DMEM[addr - BES(0x000)];
        addr += 0x001;
        addr &= 0x00000FFF;
        VR_U(vt, e+0x1) = DMEM[addr + BES(0x000)];
        VR_S(vt, e+0x2) = *(pi16)(DMEM + addr + 0x001);
        VR_A(vt, e+0x4) = DMEM[addr + BES(0x003)];
        VR_U(vt, e+0x5) = DMEM[addr + BES(0x004)];
        VR_S(vt, e+0x6) = *(pi16)(DMEM + addr + 0x005);
        break;
    }
    return;
}
void SBV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    const unsigned int e = element;

    addr = (SR[base] + 1*offset) & 0x00000FFF;
    DMEM[BES(addr)] = VR_B(vt, e);
    return;
}
void SSV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    const unsigned int e = element;

    addr = (SR[base] + 2*offset) & 0x00000FFF;
    DMEM[BES(addr)] = VR_B(vt, (e + 0x0));
    addr = (addr + 0x00000001) & 0x00000FFF;
    DMEM[BES(addr)] = VR_B(vt, (e + 0x1) & 0xF);
    return;
}
void SLV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    signed int correction;
    register u32 addr;
    const unsigned int e = element;

    if ((e & 0x1) || e > 0xC) {
        message("SLV\nIllegal element.");
        return;
    } /* must support illegal even elements in F3DEX2 */
    addr = (SR[base] + 4*offset) & 0x00000FFF;
    if (addr & 0x00000001) {
        message("SLV\nOdd addr.");
        return;
    }
    correction = HES(0x000)*(addr%0x004 - 1);
    *(pi16)(DMEM + addr - correction) = VR_S(vt, e+0x0);
    addr = (addr + 0x00000002) & 0x00000FFF; /* F3DLX 0.95:  "Mario Kart 64" */
    *(pi16)(DMEM + addr + correction) = VR_S(vt, e+0x2);
    return;
}
void SDV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    const unsigned int e = element;

    addr = (SR[base] + 8*offset) & 0x00000FFF;
    if (e > 0x8 || (e & 0x1)) {
        register unsigned int i;

#if (VR_STATIC_WRAPAROUND == 1)
        vector_copy(VR[vt] + N, VR[vt]);
        for (i = 0; i < 8; i++)
            DMEM[BES(addr++ & 0x00000FFF)] = VR_B(vt, e + i);
#else
        for (i = 0; i < 8; i++)
            DMEM[BES(addr++ & 0x00000FFF)] = VR_B(vt, (e+i)&0xF);
#endif
        return;
    } /* Illegal elements with Boss Game Studios publications. */
    switch (addr & 07) {
    case 00:
        *(pi16)(DMEM + addr + HES(0x000)) = VR_S(vt, e+0x0);
        *(pi16)(DMEM + addr + HES(0x002)) = VR_S(vt, e+0x2);
        *(pi16)(DMEM + addr + HES(0x004)) = VR_S(vt, e+0x4);
        *(pi16)(DMEM + addr + HES(0x006)) = VR_S(vt, e+0x6);
        break;
    case 01: /* "Tetrisphere" audio ucode */
        *(pi16)(DMEM + addr + 0x000) = VR_S(vt, e+0x0);
        DMEM[addr + 0x002 - BES(0x000)] = VR_A(vt, e+0x2);
        DMEM[addr + 0x003 + BES(0x000)] = VR_U(vt, e+0x3);
        *(pi16)(DMEM + addr + 0x004) = VR_S(vt, e+0x4);
        DMEM[addr + 0x006 - BES(0x000)] = VR_A(vt, e+0x6);
        addr += 0x007 + BES(0x000);
        addr &= 0x00000FFF;
        DMEM[addr] = VR_U(vt, e+0x7);
        break;
    case 02:
        *(pi16)(DMEM + addr + 0x000 - HES(0x000)) = VR_S(vt, e+0x0);
        *(pi16)(DMEM + addr + 0x002 + HES(0x000)) = VR_S(vt, e+0x2);
        *(pi16)(DMEM + addr + 0x004 - HES(0x000)) = VR_S(vt, e+0x4);
        addr += 0x006 + HES(0x000);
        addr &= 0x00000FFF;
        *(pi16)(DMEM + addr) = VR_S(vt, e+0x6);
        break;
    case 03: /* "Tetrisphere" audio ucode */
        DMEM[addr + 0x000 - BES(0x000)] = VR_A(vt, e+0x0);
        DMEM[addr + 0x001 + BES(0x000)] = VR_U(vt, e+0x1);
        *(pi16)(DMEM + addr + 0x002) = VR_S(vt, e+0x2);
        DMEM[addr + 0x004 - BES(0x000)] = VR_A(vt, e+0x4);
        addr += 0x005 + BES(0x000);
        addr &= 0x00000FFF;
        DMEM[addr] = VR_U(vt, e+0x5);
        *(pi16)(DMEM + addr + 0x001 - BES(0x000)) = VR_S(vt, 0x6);
        break;
    case 04:
        *(pi16)(DMEM + addr + HES(0x000)) = VR_S(vt, e+0x0);
        *(pi16)(DMEM + addr + HES(0x002)) = VR_S(vt, e+0x2);
        addr = (addr + 0x004) & 0x00000FFF;
        *(pi16)(DMEM + addr + HES(0x000)) = VR_S(vt, e+0x4);
        *(pi16)(DMEM + addr + HES(0x002)) = VR_S(vt, e+0x6);
        break;
    case 05: /* "Tetrisphere" audio ucode */
        *(pi16)(DMEM + addr + 0x000) = VR_S(vt, e+0x0);
        DMEM[addr + 0x002 - BES(0x000)] = VR_A(vt, e+0x2);
        addr = (addr + 0x003) & 0x00000FFF;
        DMEM[addr + BES(0x000)] = VR_U(vt, e+0x3);
        *(pi16)(DMEM + addr + 0x001) = VR_S(vt, e+0x4);
        DMEM[addr + BES(0x003)] = VR_A(vt, e+0x6);
        DMEM[addr + BES(0x004)] = VR_U(vt, e+0x7);
        break;
    case 06:
        *(pi16)(DMEM + addr - HES(0x000)) = VR_S(vt, e+0x0);
        addr = (addr + 0x002) & 0x00000FFF;
        *(pi16)(DMEM + addr + HES(0x000)) = VR_S(vt, e+0x2);
        *(pi16)(DMEM + addr + HES(0x002)) = VR_S(vt, e+0x4);
        *(pi16)(DMEM + addr + HES(0x004)) = VR_S(vt, e+0x6);
        break;
    case 07: /* "Tetrisphere" audio ucode */
        DMEM[addr - BES(0x000)] = VR_A(vt, e+0x0);
        addr = (addr + 0x001) & 0x00000FFF;
        DMEM[addr + BES(0x000)] = VR_U(vt, e+0x1);
        *(pi16)(DMEM + addr + 0x001) = VR_S(vt, e+0x2);
        DMEM[addr + BES(0x003)] = VR_A(vt, e+0x4);
        DMEM[addr + BES(0x004)] = VR_U(vt, e+0x5);
        *(pi16)(DMEM + addr + 0x005) = VR_S(vt, e+0x6);
        break;
    }
    return;
}

static char transfer_debug[32] = "?WC2    $v00[0x0], 0x000($00)";
static const char digits[16] = {
    '0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'
};

NOINLINE void res_lsw(
    unsigned vt,
    unsigned element,
    signed offset,
    unsigned base)
{
    transfer_debug[10] = '0' + (unsigned char)vt/10;
    transfer_debug[11] = '0' + (unsigned char)vt%10;

    transfer_debug[15] = digits[element & 0xF];

    transfer_debug[21] = digits[(offset & 0xFFF) >>  8];
    transfer_debug[22] = digits[(offset & 0x0FF) >>  4];
    transfer_debug[23] = digits[(offset & 0x00F) >>  0];

    transfer_debug[26] = '0' + (unsigned char)base/10;
    transfer_debug[27] = '0' + (unsigned char)base%10;

    message(transfer_debug);
    return;
}

/*
 * Group II vector loads and stores:
 * PV and UV (As of RCP implementation, XV and ZV are reserved opcodes.)
 */
void LPV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register int b;
    const unsigned int e = element;

    if (e != 0x0) {
        message("LPV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 8*offset) & 0x00000FFF;
    b = addr & 07;
    addr &= ~07;
    switch (b) {
    case 00:
        VR[vt][07] = DMEM[addr + BES(0x007)] << 8;
        VR[vt][06] = DMEM[addr + BES(0x006)] << 8;
        VR[vt][05] = DMEM[addr + BES(0x005)] << 8;
        VR[vt][04] = DMEM[addr + BES(0x004)] << 8;
        VR[vt][03] = DMEM[addr + BES(0x003)] << 8;
        VR[vt][02] = DMEM[addr + BES(0x002)] << 8;
        VR[vt][01] = DMEM[addr + BES(0x001)] << 8;
        VR[vt][00] = DMEM[addr + BES(0x000)] << 8;
        break;
    case 01: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CPU CFB */
        VR[vt][00] = DMEM[addr + BES(0x001)] << 8;
        VR[vt][01] = DMEM[addr + BES(0x002)] << 8;
        VR[vt][02] = DMEM[addr + BES(0x003)] << 8;
        VR[vt][03] = DMEM[addr + BES(0x004)] << 8;
        VR[vt][04] = DMEM[addr + BES(0x005)] << 8;
        VR[vt][05] = DMEM[addr + BES(0x006)] << 8;
        VR[vt][06] = DMEM[addr + BES(0x007)] << 8;
        addr += BES(0x008);
        addr &= 0x00000FFF;
        VR[vt][07] = DMEM[addr] << 8;
        break;
    case 02: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CPU CFB */
        VR[vt][00] = DMEM[addr + BES(0x002)] << 8;
        VR[vt][01] = DMEM[addr + BES(0x003)] << 8;
        VR[vt][02] = DMEM[addr + BES(0x004)] << 8;
        VR[vt][03] = DMEM[addr + BES(0x005)] << 8;
        VR[vt][04] = DMEM[addr + BES(0x006)] << 8;
        VR[vt][05] = DMEM[addr + BES(0x007)] << 8;
        addr += 0x008;
        addr &= 0x00000FFF;
        VR[vt][06] = DMEM[addr + BES(0x000)] << 8;
        VR[vt][07] = DMEM[addr + BES(0x001)] << 8;
        break;
    case 03: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CPU CFB */
        VR[vt][00] = DMEM[addr + BES(0x003)] << 8;
        VR[vt][01] = DMEM[addr + BES(0x004)] << 8;
        VR[vt][02] = DMEM[addr + BES(0x005)] << 8;
        VR[vt][03] = DMEM[addr + BES(0x006)] << 8;
        VR[vt][04] = DMEM[addr + BES(0x007)] << 8;
        addr += 0x008;
        addr &= 0x00000FFF;
        VR[vt][05] = DMEM[addr + BES(0x000)] << 8;
        VR[vt][06] = DMEM[addr + BES(0x001)] << 8;
        VR[vt][07] = DMEM[addr + BES(0x002)] << 8;
        break;
    case 04: /* "Resident Evil 2" in-game 3-D, F3DLX 2.08--"WWF No Mercy" */
        VR[vt][00] = DMEM[addr + BES(0x004)] << 8;
        VR[vt][01] = DMEM[addr + BES(0x005)] << 8;
        VR[vt][02] = DMEM[addr + BES(0x006)] << 8;
        VR[vt][03] = DMEM[addr + BES(0x007)] << 8;
        addr += 0x008;
        addr &= 0x00000FFF;
        VR[vt][04] = DMEM[addr + BES(0x000)] << 8;
        VR[vt][05] = DMEM[addr + BES(0x001)] << 8;
        VR[vt][06] = DMEM[addr + BES(0x002)] << 8;
        VR[vt][07] = DMEM[addr + BES(0x003)] << 8;
        break;
    case 05: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CPU CFB */
        VR[vt][00] = DMEM[addr + BES(0x005)] << 8;
        VR[vt][01] = DMEM[addr + BES(0x006)] << 8;
        VR[vt][02] = DMEM[addr + BES(0x007)] << 8;
        addr += 0x008;
        addr &= 0x00000FFF;
        VR[vt][03] = DMEM[addr + BES(0x000)] << 8;
        VR[vt][04] = DMEM[addr + BES(0x001)] << 8;
        VR[vt][05] = DMEM[addr + BES(0x002)] << 8;
        VR[vt][06] = DMEM[addr + BES(0x003)] << 8;
        VR[vt][07] = DMEM[addr + BES(0x004)] << 8;
        break;
    case 06: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CPU CFB */
        VR[vt][00] = DMEM[addr + BES(0x006)] << 8;
        VR[vt][01] = DMEM[addr + BES(0x007)] << 8;
        addr += 0x008;
        addr &= 0x00000FFF;
        VR[vt][02] = DMEM[addr + BES(0x000)] << 8;
        VR[vt][03] = DMEM[addr + BES(0x001)] << 8;
        VR[vt][04] = DMEM[addr + BES(0x002)] << 8;
        VR[vt][05] = DMEM[addr + BES(0x003)] << 8;
        VR[vt][06] = DMEM[addr + BES(0x004)] << 8;
        VR[vt][07] = DMEM[addr + BES(0x005)] << 8;
        break;
    case 07: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CPU CFB */
        VR[vt][00] = DMEM[addr + BES(0x007)] << 8;
        addr += 0x008;
        addr &= 0x00000FFF;
        VR[vt][01] = DMEM[addr + BES(0x000)] << 8;
        VR[vt][02] = DMEM[addr + BES(0x001)] << 8;
        VR[vt][03] = DMEM[addr + BES(0x002)] << 8;
        VR[vt][04] = DMEM[addr + BES(0x003)] << 8;
        VR[vt][05] = DMEM[addr + BES(0x004)] << 8;
        VR[vt][06] = DMEM[addr + BES(0x005)] << 8;
        VR[vt][07] = DMEM[addr + BES(0x006)] << 8;
        break;
    }
    return;
}
void LUV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register unsigned int b;
    const unsigned int e = element;

    addr = (SR[base] + 8*offset) & 0x00000FFF;
    if (e != 0x0) {
        addr += (~e + 0x1) & 0xF;
        for (b = 0; b < 8; b++) {
            VR[vt][b] = DMEM[BES(addr &= 0x00000FFF)] << 7;
            addr -= 16 * (e - b - 1 == 0x0);
            ++addr;
        }
        return;
    } /* "Mia Hamm Soccer 64" SP exception override (zilmar) */
    b = addr & 07;
    addr &= ~07;
    switch (b) {
    case 00:
        VR[vt][07] = DMEM[addr + BES(0x007)] << 7;
        VR[vt][06] = DMEM[addr + BES(0x006)] << 7;
        VR[vt][05] = DMEM[addr + BES(0x005)] << 7;
        VR[vt][04] = DMEM[addr + BES(0x004)] << 7;
        VR[vt][03] = DMEM[addr + BES(0x003)] << 7;
        VR[vt][02] = DMEM[addr + BES(0x002)] << 7;
        VR[vt][01] = DMEM[addr + BES(0x001)] << 7;
        VR[vt][00] = DMEM[addr + BES(0x000)] << 7;
        break;
    case 01: /* PKMN Puzzle League HVQM decoder */
        VR[vt][00] = DMEM[addr + BES(0x001)] << 7;
        VR[vt][01] = DMEM[addr + BES(0x002)] << 7;
        VR[vt][02] = DMEM[addr + BES(0x003)] << 7;
        VR[vt][03] = DMEM[addr + BES(0x004)] << 7;
        VR[vt][04] = DMEM[addr + BES(0x005)] << 7;
        VR[vt][05] = DMEM[addr + BES(0x006)] << 7;
        VR[vt][06] = DMEM[addr + BES(0x007)] << 7;
        addr += BES(0x008);
        addr &= 0x00000FFF;
        VR[vt][07] = DMEM[addr] << 7;
        break;
    case 02: /* PKMN Puzzle League HVQM decoder */
        VR[vt][00] = DMEM[addr + BES(0x002)] << 7;
        VR[vt][01] = DMEM[addr + BES(0x003)] << 7;
        VR[vt][02] = DMEM[addr + BES(0x004)] << 7;
        VR[vt][03] = DMEM[addr + BES(0x005)] << 7;
        VR[vt][04] = DMEM[addr + BES(0x006)] << 7;
        VR[vt][05] = DMEM[addr + BES(0x007)] << 7;
        addr += 0x008;
        addr &= 0x00000FFF;
        VR[vt][06] = DMEM[addr + BES(0x000)] << 7;
        VR[vt][07] = DMEM[addr + BES(0x001)] << 7;
        break;
    case 03: /* PKMN Puzzle League HVQM decoder */
        VR[vt][00] = DMEM[addr + BES(0x003)] << 7;
        VR[vt][01] = DMEM[addr + BES(0x004)] << 7;
        VR[vt][02] = DMEM[addr + BES(0x005)] << 7;
        VR[vt][03] = DMEM[addr + BES(0x006)] << 7;
        VR[vt][04] = DMEM[addr + BES(0x007)] << 7;
        addr += 0x008;
        addr &= 0x00000FFF;
        VR[vt][05] = DMEM[addr + BES(0x000)] << 7;
        VR[vt][06] = DMEM[addr + BES(0x001)] << 7;
        VR[vt][07] = DMEM[addr + BES(0x002)] << 7;
        break;
    case 04: /* PKMN Puzzle League HVQM decoder */
        VR[vt][00] = DMEM[addr + BES(0x004)] << 7;
        VR[vt][01] = DMEM[addr + BES(0x005)] << 7;
        VR[vt][02] = DMEM[addr + BES(0x006)] << 7;
        VR[vt][03] = DMEM[addr + BES(0x007)] << 7;
        addr += 0x008;
        addr &= 0x00000FFF;
        VR[vt][04] = DMEM[addr + BES(0x000)] << 7;
        VR[vt][05] = DMEM[addr + BES(0x001)] << 7;
        VR[vt][06] = DMEM[addr + BES(0x002)] << 7;
        VR[vt][07] = DMEM[addr + BES(0x003)] << 7;
        break;
    case 05: /* PKMN Puzzle League HVQM decoder */
        VR[vt][00] = DMEM[addr + BES(0x005)] << 7;
        VR[vt][01] = DMEM[addr + BES(0x006)] << 7;
        VR[vt][02] = DMEM[addr + BES(0x007)] << 7;
        addr += 0x008;
        addr &= 0x00000FFF;
        VR[vt][03] = DMEM[addr + BES(0x000)] << 7;
        VR[vt][04] = DMEM[addr + BES(0x001)] << 7;
        VR[vt][05] = DMEM[addr + BES(0x002)] << 7;
        VR[vt][06] = DMEM[addr + BES(0x003)] << 7;
        VR[vt][07] = DMEM[addr + BES(0x004)] << 7;
        break;
    case 06: /* PKMN Puzzle League HVQM decoder */
        VR[vt][00] = DMEM[addr + BES(0x006)] << 7;
        VR[vt][01] = DMEM[addr + BES(0x007)] << 7;
        addr += 0x008;
        addr &= 0x00000FFF;
        VR[vt][02] = DMEM[addr + BES(0x000)] << 7;
        VR[vt][03] = DMEM[addr + BES(0x001)] << 7;
        VR[vt][04] = DMEM[addr + BES(0x002)] << 7;
        VR[vt][05] = DMEM[addr + BES(0x003)] << 7;
        VR[vt][06] = DMEM[addr + BES(0x004)] << 7;
        VR[vt][07] = DMEM[addr + BES(0x005)] << 7;
        break;
    case 07: /* PKMN Puzzle League HVQM decoder */
        VR[vt][00] = DMEM[addr + BES(0x007)] << 7;
        addr += 0x008;
        addr &= 0x00000FFF;
        VR[vt][01] = DMEM[addr + BES(0x000)] << 7;
        VR[vt][02] = DMEM[addr + BES(0x001)] << 7;
        VR[vt][03] = DMEM[addr + BES(0x002)] << 7;
        VR[vt][04] = DMEM[addr + BES(0x003)] << 7;
        VR[vt][05] = DMEM[addr + BES(0x004)] << 7;
        VR[vt][06] = DMEM[addr + BES(0x005)] << 7;
        VR[vt][07] = DMEM[addr + BES(0x006)] << 7;
        break;
    }
    return;
}
void SPV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register unsigned int b;
    const unsigned int e = element;

    if (e != 0x0) {
        message("SPV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 8*offset) & 0x00000FFF;
    b = addr & 07;
    addr &= ~07;
    switch (b) {
    case 00:
        DMEM[addr + BES(0x007)] = (u8)(VR[vt][07] >> 8);
        DMEM[addr + BES(0x006)] = (u8)(VR[vt][06] >> 8);
        DMEM[addr + BES(0x005)] = (u8)(VR[vt][05] >> 8);
        DMEM[addr + BES(0x004)] = (u8)(VR[vt][04] >> 8);
        DMEM[addr + BES(0x003)] = (u8)(VR[vt][03] >> 8);
        DMEM[addr + BES(0x002)] = (u8)(VR[vt][02] >> 8);
        DMEM[addr + BES(0x001)] = (u8)(VR[vt][01] >> 8);
        DMEM[addr + BES(0x000)] = (u8)(VR[vt][00] >> 8);
        break;
    case 01: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CPU CFB */
        DMEM[addr + BES(0x001)] = (u8)(VR[vt][00] >> 8);
        DMEM[addr + BES(0x002)] = (u8)(VR[vt][01] >> 8);
        DMEM[addr + BES(0x003)] = (u8)(VR[vt][02] >> 8);
        DMEM[addr + BES(0x004)] = (u8)(VR[vt][03] >> 8);
        DMEM[addr + BES(0x005)] = (u8)(VR[vt][04] >> 8);
        DMEM[addr + BES(0x006)] = (u8)(VR[vt][05] >> 8);
        DMEM[addr + BES(0x007)] = (u8)(VR[vt][06] >> 8);
        addr += BES(0x008);
        addr &= 0x00000FFF;
        DMEM[addr] = (u8)(VR[vt][07] >> 8);
        break;
    case 02: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CPU CFB */
        DMEM[addr + BES(0x002)] = (u8)(VR[vt][00] >> 8);
        DMEM[addr + BES(0x003)] = (u8)(VR[vt][01] >> 8);
        DMEM[addr + BES(0x004)] = (u8)(VR[vt][02] >> 8);
        DMEM[addr + BES(0x005)] = (u8)(VR[vt][03] >> 8);
        DMEM[addr + BES(0x006)] = (u8)(VR[vt][04] >> 8);
        DMEM[addr + BES(0x007)] = (u8)(VR[vt][05] >> 8);
        addr += 0x008;
        addr &= 0x00000FFF;
        DMEM[addr + BES(0x000)] = (u8)(VR[vt][06] >> 8);
        DMEM[addr + BES(0x001)] = (u8)(VR[vt][07] >> 8);
        break;
    case 03: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CPU CFB */
        DMEM[addr + BES(0x003)] = (u8)(VR[vt][00] >> 8);
        DMEM[addr + BES(0x004)] = (u8)(VR[vt][01] >> 8);
        DMEM[addr + BES(0x005)] = (u8)(VR[vt][02] >> 8);
        DMEM[addr + BES(0x006)] = (u8)(VR[vt][03] >> 8);
        DMEM[addr + BES(0x007)] = (u8)(VR[vt][04] >> 8);
        addr += 0x008;
        addr &= 0x00000FFF;
        DMEM[addr + BES(0x000)] = (u8)(VR[vt][05] >> 8);
        DMEM[addr + BES(0x001)] = (u8)(VR[vt][06] >> 8);
        DMEM[addr + BES(0x002)] = (u8)(VR[vt][07] >> 8);
        break;
    case 04: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CPU CFB */
        DMEM[addr + BES(0x004)] = (u8)(VR[vt][00] >> 8);
        DMEM[addr + BES(0x005)] = (u8)(VR[vt][01] >> 8);
        DMEM[addr + BES(0x006)] = (u8)(VR[vt][02] >> 8);
        DMEM[addr + BES(0x007)] = (u8)(VR[vt][03] >> 8);
        addr += 0x008;
        addr &= 0x00000FFF;
        DMEM[addr + BES(0x000)] = (u8)(VR[vt][04] >> 8);
        DMEM[addr + BES(0x001)] = (u8)(VR[vt][05] >> 8);
        DMEM[addr + BES(0x002)] = (u8)(VR[vt][06] >> 8);
        DMEM[addr + BES(0x003)] = (u8)(VR[vt][07] >> 8);
        break;
    case 05: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CPU CFB */
        DMEM[addr + BES(0x005)] = (u8)(VR[vt][00] >> 8);
        DMEM[addr + BES(0x006)] = (u8)(VR[vt][01] >> 8);
        DMEM[addr + BES(0x007)] = (u8)(VR[vt][02] >> 8);
        addr += 0x008;
        addr &= 0x00000FFF;
        DMEM[addr + BES(0x000)] = (u8)(VR[vt][03] >> 8);
        DMEM[addr + BES(0x001)] = (u8)(VR[vt][04] >> 8);
        DMEM[addr + BES(0x002)] = (u8)(VR[vt][05] >> 8);
        DMEM[addr + BES(0x003)] = (u8)(VR[vt][06] >> 8);
        DMEM[addr + BES(0x004)] = (u8)(VR[vt][07] >> 8);
        break;
    case 06: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CPU CFB */
        DMEM[addr + BES(0x006)] = (u8)(VR[vt][00] >> 8);
        DMEM[addr + BES(0x007)] = (u8)(VR[vt][01] >> 8);
        addr += 0x008;
        addr &= 0x00000FFF;
        DMEM[addr + BES(0x000)] = (u8)(VR[vt][02] >> 8);
        DMEM[addr + BES(0x001)] = (u8)(VR[vt][03] >> 8);
        DMEM[addr + BES(0x002)] = (u8)(VR[vt][04] >> 8);
        DMEM[addr + BES(0x003)] = (u8)(VR[vt][05] >> 8);
        DMEM[addr + BES(0x004)] = (u8)(VR[vt][06] >> 8);
        DMEM[addr + BES(0x005)] = (u8)(VR[vt][07] >> 8);
        break;
    case 07: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CPU CFB */
        DMEM[addr + BES(0x007)] = (u8)(VR[vt][00] >> 8);
        addr += 0x008;
        addr &= 0x00000FFF;
        DMEM[addr + BES(0x000)] = (u8)(VR[vt][01] >> 8);
        DMEM[addr + BES(0x001)] = (u8)(VR[vt][02] >> 8);
        DMEM[addr + BES(0x002)] = (u8)(VR[vt][03] >> 8);
        DMEM[addr + BES(0x003)] = (u8)(VR[vt][04] >> 8);
        DMEM[addr + BES(0x004)] = (u8)(VR[vt][05] >> 8);
        DMEM[addr + BES(0x005)] = (u8)(VR[vt][06] >> 8);
        DMEM[addr + BES(0x006)] = (u8)(VR[vt][07] >> 8);
        break;
    }
    return;
}
void SUV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register unsigned int b;
    const unsigned int e = element;

    if (e != 0x0) {
        message("SUV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 8*offset) & 0x00000FFF;
    b = addr & 07;
    addr &= ~07;
    switch (b) {
    case 00:
        DMEM[addr + BES(0x007)] = (u8)(VR[vt][07] >> 7);
        DMEM[addr + BES(0x006)] = (u8)(VR[vt][06] >> 7);
        DMEM[addr + BES(0x005)] = (u8)(VR[vt][05] >> 7);
        DMEM[addr + BES(0x004)] = (u8)(VR[vt][04] >> 7);
        DMEM[addr + BES(0x003)] = (u8)(VR[vt][03] >> 7);
        DMEM[addr + BES(0x002)] = (u8)(VR[vt][02] >> 7);
        DMEM[addr + BES(0x001)] = (u8)(VR[vt][01] >> 7);
        DMEM[addr + BES(0x000)] = (u8)(VR[vt][00] >> 7);
        break;
    case 04: /* "Indiana Jones and the Infernal Machine" in-game */
        DMEM[addr + BES(0x004)] = (u8)(VR[vt][00] >> 7);
        DMEM[addr + BES(0x005)] = (u8)(VR[vt][01] >> 7);
        DMEM[addr + BES(0x006)] = (u8)(VR[vt][02] >> 7);
        DMEM[addr + BES(0x007)] = (u8)(VR[vt][03] >> 7);
        addr += 0x008;
        addr &= 0x00000FFF;
        DMEM[addr + BES(0x000)] = (u8)(VR[vt][04] >> 7);
        DMEM[addr + BES(0x001)] = (u8)(VR[vt][05] >> 7);
        DMEM[addr + BES(0x002)] = (u8)(VR[vt][06] >> 7);
        DMEM[addr + BES(0x003)] = (u8)(VR[vt][07] >> 7);
        break;
    default: /* Completely legal, just never seen it be done. */
        message("SUV\nWeird addr.");
    }
    return;
}

/*
 * Group III vector loads and stores:
 * HV, FV, and AV (As of RCP implementation, AV opcodes are reserved.)
 */
void LHV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    const unsigned int e = element;

    if (e != 0x0) {
        message("LHV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (addr & 0x0000000E) {
        message("LHV\nIllegal addr.");
        return;
    }
    addr ^= MES(00);
    VR[vt][07] = DMEM[addr + HES(0x00E)] << 7;
    VR[vt][06] = DMEM[addr + HES(0x00C)] << 7;
    VR[vt][05] = DMEM[addr + HES(0x00A)] << 7;
    VR[vt][04] = DMEM[addr + HES(0x008)] << 7;
    VR[vt][03] = DMEM[addr + HES(0x006)] << 7;
    VR[vt][02] = DMEM[addr + HES(0x004)] << 7;
    VR[vt][01] = DMEM[addr + HES(0x002)] << 7;
    VR[vt][00] = DMEM[addr + HES(0x000)] << 7;
    return;
}
void LFV(unsigned vt, unsigned element, signed offset, unsigned base)
{ /* Dummy implementation only:  Do any games execute this? */
    res_lsw(vt, element, offset, base);
    return;
}
void SHV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    const unsigned int e = element;

    if (e != 0x0) {
        message("SHV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (addr & 0x0000000E) {
        message("SHV\nIllegal addr.");
        return;
    }
    addr ^= MES(00);
    DMEM[addr + HES(0x00E)] = (u8)(VR[vt][07] >> 7);
    DMEM[addr + HES(0x00C)] = (u8)(VR[vt][06] >> 7);
    DMEM[addr + HES(0x00A)] = (u8)(VR[vt][05] >> 7);
    DMEM[addr + HES(0x008)] = (u8)(VR[vt][04] >> 7);
    DMEM[addr + HES(0x006)] = (u8)(VR[vt][03] >> 7);
    DMEM[addr + HES(0x004)] = (u8)(VR[vt][02] >> 7);
    DMEM[addr + HES(0x002)] = (u8)(VR[vt][01] >> 7);
    DMEM[addr + HES(0x000)] = (u8)(VR[vt][00] >> 7);
    return;
}
void SFV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    const unsigned int e = element;

    addr = (SR[base] + 16*offset) & 0x00000FFF;
    addr &= 0x00000FF3;
    addr ^= BES(00);
    switch (e) {
    case 0x0:
        DMEM[addr + 0x000] = (u8)(VR[vt][00] >> 7);
        DMEM[addr + 0x004] = (u8)(VR[vt][01] >> 7);
        DMEM[addr + 0x008] = (u8)(VR[vt][02] >> 7);
        DMEM[addr + 0x00C] = (u8)(VR[vt][03] >> 7);
        break;
    case 0x8:
        DMEM[addr + 0x000] = (u8)(VR[vt][04] >> 7);
        DMEM[addr + 0x004] = (u8)(VR[vt][05] >> 7);
        DMEM[addr + 0x008] = (u8)(VR[vt][06] >> 7);
        DMEM[addr + 0x00C] = (u8)(VR[vt][07] >> 7);
        break;
    default:
        message("SFV\nIllegal element.");
    }
    return;
}

/*
 * Group IV vector loads and stores:
 * QV and RV
 */
void LQV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register unsigned int b;
    const unsigned int e = element; /* Boss Game Studios illegal elements */

    if (e & 0x1) {
        message("LQV\nOdd element.");
        return;
    }
    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (addr & 0x00000001) {
        message("LQV\nOdd addr.");
        return;
    }
    b = addr & 0x0000000F;

    addr &= ~0x0000000F;
    switch (b/2) { /* mistake in SGI patent regarding LQV */
    case 0x0/2:
        VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x000));
        VR_S(vt,e+0x2) = *(pi16)(DMEM + addr + HES(0x002));
        VR_S(vt,e+0x4) = *(pi16)(DMEM + addr + HES(0x004));
        VR_S(vt,e+0x6) = *(pi16)(DMEM + addr + HES(0x006));
        VR_S(vt,e+0x8) = *(pi16)(DMEM + addr + HES(0x008));
        VR_S(vt,e+0xA) = *(pi16)(DMEM + addr + HES(0x00A));
        VR_S(vt,e+0xC) = *(pi16)(DMEM + addr + HES(0x00C));
        VR_S(vt,e+0xE) = *(pi16)(DMEM + addr + HES(0x00E));
        break;
    case 0x2/2:
        VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x002));
        VR_S(vt,e+0x2) = *(pi16)(DMEM + addr + HES(0x004));
        VR_S(vt,e+0x4) = *(pi16)(DMEM + addr + HES(0x006));
        VR_S(vt,e+0x6) = *(pi16)(DMEM + addr + HES(0x008));
        VR_S(vt,e+0x8) = *(pi16)(DMEM + addr + HES(0x00A));
        VR_S(vt,e+0xA) = *(pi16)(DMEM + addr + HES(0x00C));
        VR_S(vt,e+0xC) = *(pi16)(DMEM + addr + HES(0x00E));
        break;
    case 0x4/2:
        VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x004));
        VR_S(vt,e+0x2) = *(pi16)(DMEM + addr + HES(0x006));
        VR_S(vt,e+0x4) = *(pi16)(DMEM + addr + HES(0x008));
        VR_S(vt,e+0x6) = *(pi16)(DMEM + addr + HES(0x00A));
        VR_S(vt,e+0x8) = *(pi16)(DMEM + addr + HES(0x00C));
        VR_S(vt,e+0xA) = *(pi16)(DMEM + addr + HES(0x00E));
        break;
    case 0x6/2:
        VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x006));
        VR_S(vt,e+0x2) = *(pi16)(DMEM + addr + HES(0x008));
        VR_S(vt,e+0x4) = *(pi16)(DMEM + addr + HES(0x00A));
        VR_S(vt,e+0x6) = *(pi16)(DMEM + addr + HES(0x00C));
        VR_S(vt,e+0x8) = *(pi16)(DMEM + addr + HES(0x00E));
        break;
    case 0x8/2: /* "Resident Evil 2" cinematics and Boss Game Studios */
        VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x008));
        VR_S(vt,e+0x2) = *(pi16)(DMEM + addr + HES(0x00A));
        VR_S(vt,e+0x4) = *(pi16)(DMEM + addr + HES(0x00C));
        VR_S(vt,e+0x6) = *(pi16)(DMEM + addr + HES(0x00E));
        break;
    case 0xA/2: /* "Conker's Bad Fur Day" audio microcode by Rareware */
        VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x00A));
        VR_S(vt,e+0x2) = *(pi16)(DMEM + addr + HES(0x00C));
        VR_S(vt,e+0x4) = *(pi16)(DMEM + addr + HES(0x00E));
        break;
    case 0xC/2: /* "Conker's Bad Fur Day" audio microcode by Rareware */
        VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x00C));
        VR_S(vt,e+0x2) = *(pi16)(DMEM + addr + HES(0x00E));
        break;
    case 0xE/2: /* "Conker's Bad Fur Day" audio microcode by Rareware */
        VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x00E));
        break;
    }
    return;
}
void LRV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register unsigned int b;
    const unsigned int e = element;

    if (e != 0x0) {
        message("LRV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (addr & 0x00000001) {
        message("LRV\nOdd addr.");
        return;
    }
    b = addr & 0x0000000F;
    addr &= ~0x0000000F;
    switch (b/2) {
    case 0xE/2:
        VR[vt][01] = *(pi16)(DMEM + addr + HES(0x000));
        VR[vt][02] = *(pi16)(DMEM + addr + HES(0x002));
        VR[vt][03] = *(pi16)(DMEM + addr + HES(0x004));
        VR[vt][04] = *(pi16)(DMEM + addr + HES(0x006));
        VR[vt][05] = *(pi16)(DMEM + addr + HES(0x008));
        VR[vt][06] = *(pi16)(DMEM + addr + HES(0x00A));
        VR[vt][07] = *(pi16)(DMEM + addr + HES(0x00C));
        break;
    case 0xC/2:
        VR[vt][02] = *(pi16)(DMEM + addr + HES(0x000));
        VR[vt][03] = *(pi16)(DMEM + addr + HES(0x002));
        VR[vt][04] = *(pi16)(DMEM + addr + HES(0x004));
        VR[vt][05] = *(pi16)(DMEM + addr + HES(0x006));
        VR[vt][06] = *(pi16)(DMEM + addr + HES(0x008));
        VR[vt][07] = *(pi16)(DMEM + addr + HES(0x00A));
        break;
    case 0xA/2:
        VR[vt][03] = *(pi16)(DMEM + addr + HES(0x000));
        VR[vt][04] = *(pi16)(DMEM + addr + HES(0x002));
        VR[vt][05] = *(pi16)(DMEM + addr + HES(0x004));
        VR[vt][06] = *(pi16)(DMEM + addr + HES(0x006));
        VR[vt][07] = *(pi16)(DMEM + addr + HES(0x008));
        break;
    case 0x8/2:
        VR[vt][04] = *(pi16)(DMEM + addr + HES(0x000));
        VR[vt][05] = *(pi16)(DMEM + addr + HES(0x002));
        VR[vt][06] = *(pi16)(DMEM + addr + HES(0x004));
        VR[vt][07] = *(pi16)(DMEM + addr + HES(0x006));
        break;
    case 0x6/2:
        VR[vt][05] = *(pi16)(DMEM + addr + HES(0x000));
        VR[vt][06] = *(pi16)(DMEM + addr + HES(0x002));
        VR[vt][07] = *(pi16)(DMEM + addr + HES(0x004));
        break;
    case 0x4/2:
        VR[vt][06] = *(pi16)(DMEM + addr + HES(0x000));
        VR[vt][07] = *(pi16)(DMEM + addr + HES(0x002));
        break;
    case 0x2/2:
        VR[vt][07] = *(pi16)(DMEM + addr + HES(0x000));
        break;
    case 0x0/2:
        break;
    }
    return;
}
void SQV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register unsigned int b;
    const unsigned int e = element;

    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (e != 0x0) {
        register unsigned int i;

#if (VR_STATIC_WRAPAROUND == 1)
        vector_copy(VR[vt] + N, VR[vt]);
        for (i = 0; i < 16 - addr%16; i++)
            DMEM[BES((addr + i) & 0xFFF)] = VR_B(vt, e + i);
#else
        for (i = 0; i < 16 - addr%16; i++)
            DMEM[BES((addr + i) & 0xFFF)] = VR_B(vt, (e + i) & 0xF);
#endif
        return;
    } /* illegal SQV, happens with "Mia Hamm Soccer 64" */
    b = addr & 0x0000000F;
    addr &= ~0x0000000F;
    switch (b) {
    case 00:
        *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][00];
        *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][01];
        *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][02];
        *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][03];
        *(pi16)(DMEM + addr + HES(0x008)) = VR[vt][04];
        *(pi16)(DMEM + addr + HES(0x00A)) = VR[vt][05];
        *(pi16)(DMEM + addr + HES(0x00C)) = VR[vt][06];
        *(pi16)(DMEM + addr + HES(0x00E)) = VR[vt][07];
        break;
    case 02:
        *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][00];
        *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][01];
        *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][02];
        *(pi16)(DMEM + addr + HES(0x008)) = VR[vt][03];
        *(pi16)(DMEM + addr + HES(0x00A)) = VR[vt][04];
        *(pi16)(DMEM + addr + HES(0x00C)) = VR[vt][05];
        *(pi16)(DMEM + addr + HES(0x00E)) = VR[vt][06];
        break;
    case 04:
        *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][00];
        *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][01];
        *(pi16)(DMEM + addr + HES(0x008)) = VR[vt][02];
        *(pi16)(DMEM + addr + HES(0x00A)) = VR[vt][03];
        *(pi16)(DMEM + addr + HES(0x00C)) = VR[vt][04];
        *(pi16)(DMEM + addr + HES(0x00E)) = VR[vt][05];
        break;
    case 06:
        *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][00];
        *(pi16)(DMEM + addr + HES(0x008)) = VR[vt][01];
        *(pi16)(DMEM + addr + HES(0x00A)) = VR[vt][02];
        *(pi16)(DMEM + addr + HES(0x00C)) = VR[vt][03];
        *(pi16)(DMEM + addr + HES(0x00E)) = VR[vt][04];
        break;
    default:
        message("SQV\nWeird addr.");
    }
    return;
}
void SRV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register unsigned int b;
    const unsigned int e = element;

    if (e != 0x0) {
        message("SRV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (addr & 0x00000001) {
        message("SRV\nOdd addr.");
        return;
    }
    b = addr & 0x0000000F;

    addr &= ~0x0000000F;
    switch (b/2) {
    case 0xE/2:
        *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][01];
        *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][02];
        *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][03];
        *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][04];
        *(pi16)(DMEM + addr + HES(0x008)) = VR[vt][05];
        *(pi16)(DMEM + addr + HES(0x00A)) = VR[vt][06];
        *(pi16)(DMEM + addr + HES(0x00C)) = VR[vt][07];
        break;
    case 0xC/2:
        *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][02];
        *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][03];
        *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][04];
        *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][05];
        *(pi16)(DMEM + addr + HES(0x008)) = VR[vt][06];
        *(pi16)(DMEM + addr + HES(0x00A)) = VR[vt][07];
        break;
    case 0xA/2:
        *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][03];
        *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][04];
        *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][05];
        *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][06];
        *(pi16)(DMEM + addr + HES(0x008)) = VR[vt][07];
        break;
    case 0x8/2:
        *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][04];
        *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][05];
        *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][06];
        *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][07];
        break;
    case 0x6/2:
        *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][05];
        *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][06];
        *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][07];
        break;
    case 0x4/2:
        *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][06];
        *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][07];
        break;
    case 0x2/2:
        *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][07];
        break;
    case 0x0/2:
        break;
    }
    return;
}

/*
 * Group V vector loads and stores
 * TV and SWV (As of RCP implementation, LTWV opcode was undesired.)
 */
void LTV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register unsigned int i;
    const unsigned int e = element;

    if (e & 1) {
        message("LTV\nIllegal element.");
        return;
    }
    if (vt & 07) {
        message("LTV\nUncertain case!");
        return; /* For LTV I am not sure; for STV I have an idea. */
    }
    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (addr & 0x0000000F) {
        message("LTV\nIllegal addr.");
        return;
    }
    for (i = 0; i < 8; i++) /* SGI screwed LTV up on N64.  See STV instead. */
        VR[vt + i][(i - e/2) & 07] = *(pi16)(DMEM + addr + HES(2*i));
    return;
}
void SWV(unsigned vt, unsigned element, signed offset, unsigned base)
{ /* Dummy implementation only:  Do any games execute this? */
    res_lsw(vt, element, offset, base);
    return;
}
void STV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register unsigned int i;
    const unsigned int e = element;

    if (e & 1) {
        message("STV\nIllegal element.");
        return;
    }
    if (vt & 07) {
        message("STV\nUncertain case!");
        return; /* vt &= 030; */
    }
    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (addr & 0x0000000F) {
        message("STV\nIllegal addr.");
        return;
    }
    for (i = 0; i < 8; i++)
        *(pi16)(DMEM + addr + HES(2*i)) = VR[vt + (e/2 + i)%8][i];
    return;
}

int temp_PC;
#ifdef WAIT_FOR_CPU_HOST
short MFC0_count[32];
#endif

mwc2_func LWC2[2 * 8*2] = {
    LBV    ,LSV    ,LLV    ,LDV    ,LQV    ,LRV    ,LPV    ,LUV    ,
    LHV    ,LFV    ,res_lsw,LTV    ,res_lsw,res_lsw,res_lsw,res_lsw,
    res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,
    res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,
};
mwc2_func SWC2[2 * 8*2] = {
    SBV    ,SSV    ,SLV    ,SDV    ,SQV    ,SRV    ,SPV    ,SUV    ,
    SHV    ,SFV    ,SWV    ,STV    ,res_lsw,res_lsw,res_lsw,res_lsw,
    res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,
    res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,res_lsw,
};

static ALIGNED i16 shuffle_temporary[N];
#ifndef ARCH_MIN_SSE2
static const unsigned char ei[1 << 4][N] = {
    { 00, 01, 02, 03, 04, 05, 06, 07 }, /* none (vector-only operand) */
    { 00, 01, 02, 03, 04, 05, 06, 07 },
    { 00, 00, 02, 02, 04, 04, 06, 06 }, /* 0Q */
    { 01, 01, 03, 03, 05, 05, 07, 07 }, /* 1Q */
    { 00, 00, 00, 00, 04, 04, 04, 04 }, /* 0H */
    { 01, 01, 01, 01, 05, 05, 05, 05 }, /* 1H */
    { 02, 02, 02, 02, 06, 06, 06, 06 }, /* 2H */
    { 03, 03, 03, 03, 07, 07, 07, 07 }, /* 3H */
    { 00, 00, 00, 00, 00, 00, 00, 00 }, /* 0W */
    { 01, 01, 01, 01, 01, 01, 01, 01 }, /* 1W */
    { 02, 02, 02, 02, 02, 02, 02, 02 }, /* 2W */
    { 03, 03, 03, 03, 03, 03, 03, 03 }, /* 3W */
    { 04, 04, 04, 04, 04, 04, 04, 04 }, /* 4W */
    { 05, 05, 05, 05, 05, 05, 05, 05 }, /* 5W */
    { 06, 06, 06, 06, 06, 06, 06, 06 }, /* 6W */
    { 07, 07, 07, 07, 07, 07, 07, 07 }, /* 7W */
};
#endif

PROFILE_MODE int SPECIAL(u32 inst, u32 PC)
{
    unsigned int rd, rs, rt;

    rd = IW_RD(inst);
    rt = (inst >> 16) % (1 << 5);

    switch (inst % 64) {
    case 000: /* SLL */
        SR[rd] = SR[rt] << MASK_SA(inst >> 6);
        SR[zero] = 0x00000000;
        break;
    case 002: /* SRL */
        SR[rd] = (u32)(SR[rt]) >> MASK_SA(inst >> 6);
        SR[zero] = 0x00000000;
        break;
    case 003: /* SRA */
        SR[rd] = (s32)(SR[rt]) >> MASK_SA(inst >> 6);
        SR[zero] = 0x00000000;
        break;
    case 004: /* SLLV */
        rs = SPECIAL_DECODE_RS(inst);
        SR[rd] = SR[rt] << MASK_SA(SR[rs]);
        SR[zero] = 0x00000000;
        break;
    case 006: /* SRLV */
        rs = SPECIAL_DECODE_RS(inst);
        SR[rd] = (u32)(SR[rt]) >> MASK_SA(SR[rs]);
        SR[zero] = 0x00000000;
        break;
    case 007: /* SRAV */
        rs = SPECIAL_DECODE_RS(inst);
        SR[rd] = (s32)(SR[rt]) >> MASK_SA(SR[rs]);
        SR[zero] = 0x00000000;
        break;
    case 011: /* JALR */
        SR[rd] = FIT_IMEM(PC + LINK_OFF);
        SR[zero] = 0x00000000;
     /* Fall through. */
    case 010: /* JR */
        rs = SPECIAL_DECODE_RS(inst);
        set_PC(SR[rs]);
        return 1;
    case 015: /* BREAK */
        *CR[0x4] |= SP_STATUS_BROKE | SP_STATUS_HALT;
        if (*CR[0x4] & SP_STATUS_INTR_BREAK) {
            GET_RCP_REG(MI_INTR_REG) |= 0x00000001;
            GET_RSP_INFO(CheckInterrupts)();
        }
        return -1;
    case 040: /* ADD */
    case 041: /* ADDU */
        rs = SPECIAL_DECODE_RS(inst);
        SR[rd] = SR[rs] + SR[rt];
        SR[zero] = 0x00000000; /* needed for Rareware micro-codes */
        break;
    case 042: /* SUB */
    case 043: /* SUBU */
        rs = SPECIAL_DECODE_RS(inst);
        SR[rd] = SR[rs] - SR[rt];
        SR[zero] = 0x00000000;
        break;
    case 044: /* AND */
        rs = SPECIAL_DECODE_RS(inst);
        SR[rd] = SR[rs] & SR[rt];
        SR[zero] = 0x00000000; /* needed for Rareware micro-codes */
        break;
    case 045: /* OR */
        rs = SPECIAL_DECODE_RS(inst);
        SR[rd] = SR[rs] | SR[rt];
        SR[zero] = 0x00000000;
        break;
    case 046: /* XOR */
        rs = SPECIAL_DECODE_RS(inst);
        SR[rd] = SR[rs] ^ SR[rt];
        SR[zero] = 0x00000000;
        break;
    case 047: /* NOR */
        rs = SPECIAL_DECODE_RS(inst);
        SR[rd] = ~(SR[rs] | SR[rt]);
        SR[zero] = 0x00000000;
        break;
    case 052: /* SLT */
        rs = SPECIAL_DECODE_RS(inst);
        SR[rd] = ((s32)(SR[rs]) < (s32)(SR[rt]));
        SR[zero] = 0x00000000;
        break;
    case 053: /* SLTU */
        rs = SPECIAL_DECODE_RS(inst);
        SR[rd] = ((u32)(SR[rs]) < (u32)(SR[rt]));
        SR[zero] = 0x00000000;
        break;
    default:
        res_S();
    }
    return 0;
}

PROFILE_MODE int REGIMM(u32 inst, u32 PC)
{
    const unsigned int base = (inst >> 21) % (1 << 5);
    const unsigned int rt   = (inst >> 16) % (1 << 5);

    switch (rt) {
    case 020: /* BLTZAL */
        SR[ra] = FIT_IMEM(PC + LINK_OFF);
     /* Fall through. */
    case 000: /* BLTZ */
        if (!((s32)SR[base] < 0))
            return 0;
        set_PC(PC + 4*inst + SLOT_OFF);
        break;
    case 021: /* BGEZAL */
        SR[ra] = FIT_IMEM(PC + LINK_OFF);
     /* Fall through. */
    case 001: /* BGEZ */
        if (!((s32)SR[base] >= 0))
            return 0;
        set_PC(PC + 4*inst + SLOT_OFF);
        break;
    default:
        res_S();
    }
    return 1;
}

PROFILE_MODE void MWC2_load(u32 inst)
{
    s16 offset;
    const unsigned int base    = (inst >> 21) % (1 << 5);
    const unsigned int vt      = (inst >> 16) % (1 << 5);
    const unsigned int element = (inst >>  7) % (1 << 4);

#ifdef ARCH_MIN_SSE2
    offset   = (s16)inst;
    offset <<= 5 + 4; /* safe on x86, skips 5-bit rd, 4-bit element */
    offset >>= 5 + 4;
#else
    offset = (inst & 64) ? -(s16)(~inst%64 + 1) : inst % 64;
#endif
    LWC2[IW_RD(inst)](vt, element, offset, base);
}
PROFILE_MODE void MWC2_store(u32 inst)
{
    s16 offset;
    const unsigned int base    = (inst >> 21) % (1 << 5);
    const unsigned int vt      = (inst >> 16) % (1 << 5);
    const unsigned int element = (inst >>  7) % (1 << 4);

#ifdef ARCH_MIN_SSE2
    offset = (s16)inst;
    offset <<= 5 + 4; /* safe on x86, skips 5-bit rd, 4-bit element */
    offset >>= 5 + 4;
#else
    offset = (inst & 64) ? -(s16)(~inst%64 + 1) : inst % 64;
#endif
    SWC2[IW_RD(inst)](vt, element, offset, base);
}

PROFILE_MODE void COP0(u32 inst)
{
    const unsigned int rd = IW_RD(inst);
    const unsigned int rs = (inst >> 21) % (1 << 5);
    const unsigned int rt = (inst >> 16) % (1 << 5);

    switch (rs) {
    case 000:
        SP_CP0_MF(rt, rd);
        break;
    case 004:
        SP_CP0_MT[rd % NUMBER_OF_CP0_REGISTERS](rt);
        break;
    default:
        res_S();
    }
}

PROFILE_MODE void COP2(u32 inst)
{
    const unsigned int op = (inst >> 21) % (1 << 5); /* inst.R.rs */
    const unsigned int vt = (inst >> 16) % (1 << 5); /* inst.R.rt */
    const unsigned int vs = IW_RD(inst);
    const unsigned int vd = (inst >>  6) % (1 << 5); /* inst.R.sa */
    const unsigned int func = inst % (1 << 6);
#ifndef ARCH_MIN_SSE2
    const unsigned int e  = op & 0xF; /* With Intel, LEA offsets beat ANDing. */
#endif

    switch (op) {
#ifdef ARCH_MIN_SSE2
        v16 target;
#else
        register unsigned int i;
#endif

    case 000:
        MFC2(vt, vs, vd >> 1);
        break;
    case 002:
        CFC2(vt, vs);
        break;
    case 004:
        MTC2(vt, vs, vd >> 1);
        break;
    case 006:
        CTC2(vt, vs);
        break;
    case 020:
    case 021:
#ifdef ARCH_MIN_SSE2
        *(v16 *)(VR[vd]) = COP2_C2[func](*(v16 *)VR[vs], *(v16 *)VR[vt]);
#else
        COP2_C2[func](&VR[vs][0], &VR[vt][0]);
        vector_copy(&VR[vd][0], &V_result[0]);
#endif
        break;
    case 022:
    case 023:
#ifdef ARCH_MIN_SSE2
        shuffle_temporary[0] = VR[vt][0 + op - 0x12];
        shuffle_temporary[2] = VR[vt][2 + op - 0x12];
        shuffle_temporary[4] = VR[vt][4 + op - 0x12];
        shuffle_temporary[6] = VR[vt][6 + op - 0x12];
        target = *(v16 *)(&shuffle_temporary[0]);
        target = _mm_shufflehi_epi16(target, _MM_SHUFFLE(2, 2, 0, 0));
        target = _mm_shufflelo_epi16(target, _MM_SHUFFLE(2, 2, 0, 0));
        *(v16 *)(VR[vd]) = COP2_C2[func](*(v16 *)VR[vs], target);
#else
        for (i = 0; i < N; i++)
            shuffle_temporary[i] = VR[vt][(i & 0xE) + (e & 0x1)];
        COP2_C2[func](&VR[vs][0], &shuffle_temporary[0]);
        vector_copy(&VR[vd][0], &V_result[0]);
#endif
        break;
    case 024:
    case 025:
    case 026:
    case 027:
#ifdef ARCH_MIN_SSE2
        target = _mm_setzero_si128();
        target = _mm_insert_epi16(target, VR[vt][0 + op - 0x14], 0);
        target = _mm_insert_epi16(target, VR[vt][4 + op - 0x14], 4);
        target = _mm_shufflehi_epi16(target, _MM_SHUFFLE(0, 0, 0, 0));
        target = _mm_shufflelo_epi16(target, _MM_SHUFFLE(0, 0, 0, 0));
        *(v16 *)(VR[vd]) = COP2_C2[func](*(v16 *)VR[vs], target);
#else
        for (i = 0; i < N; i++)
            shuffle_temporary[i] = VR[vt][(i & 0xC) + (e & 0x3)];
        COP2_C2[func](&VR[vs][0], &shuffle_temporary[0]);
        vector_copy(&VR[vd][0], &V_result[0]);
#endif
        break;
    case 030:
    case 031:
    case 032:
    case 033:
    case 034:
    case 035:
    case 036:
    case 037:
#ifdef ARCH_MIN_SSE2
        *(v16 *)(VR[vd]) = COP2_C2[func](
            *(v16 *)VR[vs],
            _mm_set1_epi16(VR[vt][op - 0x18])
        );
#else
        for (i = 0; i < N; i++)
            shuffle_temporary[i] = VR[vt][e % N];
        COP2_C2[func](&VR[vs][0], &shuffle_temporary[0]);
        vector_copy(&VR[vd][0], &V_result[0]);
#endif
        break;
    default:
        res_S();
    }
}

NOINLINE void run_task(void)
{
    register u32 PC;

    PC = FIT_IMEM(GET_RCP_REG(SP_PC_REG));
    for (;;) {
        inst_word = *(pi32)(IMEM + FIT_IMEM(PC));
#ifdef EMULATE_STATIC_PC
        PC = (PC + 0x004);
EX:
#endif
#ifdef SP_EXECUTE_LOG
        step_SP_commands(inst_word);
#endif

#if (0 != 0)
        if (GET_RCP_REG(SP_STATUS_REG) & SP_STATUS_HALT)
            goto RSP_halted_CPU_exit_point; /* Only BREAK and COP0 set this. */
        SR[zero] = 0x00000000; /* already handled on per-instruction basis */
#endif
        switch (inst_word >> 26) {
        case 000: /* SPECIAL */
            switch (SPECIAL(inst_word, PC)) {
            case -1: /* BREAK */
                goto RSP_halted_CPU_exit_point;
            case +1: /* JR and JALR */
                JUMP;
            }
            break;
        case 001: /* REGIMM */
            if (REGIMM(inst_word, PC) != 0)
                JUMP;
            break;
        case 002:
            J(inst_word);
            JUMP;
        case 003:
            JAL(inst_word, PC);
            JUMP;
        case 004:
            if (BEQ(inst_word, PC) != 0)
                JUMP;
            break;
        case 005:
            if (BNE(inst_word, PC) != 0)
                JUMP;
            break;
        case 006:
            if (BLEZ(inst_word, PC) != 0)
                JUMP;
            break;
        case 007:
            if (BGTZ(inst_word, PC) != 0)
                JUMP;
            break;
        case 010: /* ADDI:  Traps don't exist on the RCP. */
        case 011:
            ADDIU(inst_word);
            break;
        case 012:
            SLTI(inst_word);
            break;
        case 013:
            SLTIU(inst_word);
            break;
        case 014:
            ANDI(inst_word);
            break;
        case 015:
            ORI(inst_word);
            break;
        case 016:
            XORI(inst_word);
            break;
        case 017:
            LUI(inst_word);
            break;
        case 020:
            COP0(inst_word);
            if (GET_RCP_REG(SP_STATUS_REG) & SP_STATUS_HALT)
                goto RSP_halted_CPU_exit_point;
            break;
        case 022:
            COP2(inst_word);
            break;
        case 040:
            LB(inst_word);
            break;
        case 041:
            LH(inst_word);
            break;
        case 043:
            LW(inst_word);
            break;
        case 044:
            LBU(inst_word);
            break;
        case 045:
            LHU(inst_word);
            break;
        case 050:
            SB(inst_word);
            break;
        case 051:
            SH(inst_word);
            break;
        case 053:
            SW(inst_word);
            break;
        case 062: /* LWC2 */
            MWC2_load(inst_word);
            break;
        case 072: /* SWC2 */
            MWC2_store(inst_word);
            break;
        default:
            res_S();
        }

#ifndef EMULATE_STATIC_PC
        if (stage == 2) { /* branch phase of scheduler */
            stage = 0*stage;
            PC = FIT_IMEM(temp_PC);
            GET_RCP_REG(SP_PC_REG) = temp_PC;
        } else {
            stage = 2*stage; /* next IW in branch delay slot? */
            PC = FIT_IMEM(PC + 0x004);
            GET_RCP_REG(SP_PC_REG) = 0x04001000 + PC;
        }
#else
        continue;
set_branch_delay:
        inst_word = *(pi32)(IMEM + FIT_IMEM(PC));
        PC = FIT_IMEM(temp_PC);
        goto EX;
#endif
    }
RSP_halted_CPU_exit_point:
    GET_RCP_REG(SP_PC_REG) = 0x04001000 | FIT_IMEM(PC);

    return;
}
