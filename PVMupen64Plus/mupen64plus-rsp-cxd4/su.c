/******************************************************************************\
* Project:  MSP Simulation Layer for Scalar Unit Operations                    *
* Authors:  Iconoclast                                                         *
* Release:  2015.02.24                                                         *
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

#define EMULATE_STATIC_PC

#include "su.h"

/*
 * including modular interface structure to access configuration settings...
 * Some of the parallel timing features require perfect timing or configs.
 */
#include "module.h"

int CPU_running;

u32 inst;

i32 SR[32];
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
    temp_PC = 0x04001000 + (address & 0xFFC);
#ifndef EMULATE_STATIC_PC
    stage = 1;
#endif
    return;
}

static word_32 SR_temp;

/*
 * All other behaviors defined below this point in the file are specific to
 * the SGI N64 extension to the MIPS R4000 and are not entirely implemented.
 */

pu32 CR[16];
u8 conf[32];

int MF_SP_STATUS_TIMEOUT;

void SP_CP0_MF(unsigned int rt, unsigned int rd)
{
    SR[rt] = *(CR[rd]);
    SR[0] = 0x00000000;
    if (rd == 0x7)
    {
        if (CFG_MEND_SEMAPHORE_LOCK == 0)
            return;
        if (CFG_HLE_GFX | CFG_HLE_AUD)
            return;
        GET_RCP_REG(SP_SEMAPHORE_REG) = 0x00000001;
        GET_RCP_REG(SP_STATUS_REG) |= SP_STATUS_HALT; /* temporary hack */
        CPU_running = ~GET_RCP_REG(SP_STATUS_REG) & SP_STATUS_HALT;
        return;
    }
#ifdef WAIT_FOR_CPU_HOST
    if (rd == 0x4)
    {
        ++MFC0_count[rt];
        GET_RCP_REG(SP_STATUS_REG) |= (MFC0_count[rt] >= MF_SP_STATUS_TIMEOUT);
        CPU_running = ~GET_RCP_REG(SP_STATUS_REG) & 1;
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
    CPU_running = ~GET_RCP_REG(SP_STATUS_REG) & 1;
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
    if (GET_RSP_INFO(ProcessRdpList) == NULL) /* zilmar GFX #1.2 */
        return;
    GET_RSP_INFO(ProcessRdpList)();
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

static void (*SP_CP0_MT[16])(unsigned int) = {
MT_DMA_CACHE       ,MT_DMA_DRAM        ,MT_DMA_READ_LENGTH ,MT_DMA_WRITE_LENGTH,
MT_SP_STATUS       ,MT_READ_ONLY       ,MT_READ_ONLY       ,MT_SP_RESERVED,
MT_CMD_START       ,MT_CMD_END         ,MT_READ_ONLY       ,MT_CMD_STATUS,
MT_CMD_CLOCK       ,MT_READ_ONLY       ,MT_READ_ONLY       ,MT_READ_ONLY
};

void SP_DMA_READ(void)
{
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
    do
    { /* `count` always starts > 0, so we begin with `do` instead of `while`. */
        unsigned int offC, offD; /* SP cache and dynamic DMA pointers */
        register unsigned int i = 0;

        --count;
        do
        {
            offC = (count*length + *CR[0x0] + i) & 0x00001FF8ul;
            offD = (count*skip + *CR[0x1] + i) & 0x00FFFFF8ul;
            *(pi64)(DMEM + offC) =
                *(pi64)(DRAM + offD)
              & (offD & ~MAX_DRAM_DMA_ADDR ? 0 : ~0) /* 0 if (addr > limit) */
            ;
            i += 0x008;
        } while (i < length);
    } while (count);
    GET_RCP_REG(SP_DMA_BUSY_REG)  =  0x00000000;
    GET_RCP_REG(SP_STATUS_REG)   &= ~SP_STATUS_DMA_BUSY;
    return;
}
void SP_DMA_WRITE(void)
{
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
    do
    { /* `count` always starts > 0, so we begin with `do` instead of `while`. */
        unsigned int offC, offD; /* SP cache and dynamic DMA pointers */
        register unsigned int i = 0;

        --count;
        do
        {
            offC = (count*length + *CR[0x0] + i) & 0x00001FF8ul;
            offD = (count*skip + *CR[0x1] + i) & 0x00FFFFF8ul;
            *(pi64)(DRAM + offD) = *(pi64)(DMEM + offC);
            i += 0x000008;
        } while (i < length);
    } while (count);
    GET_RCP_REG(SP_DMA_BUSY_REG)  =  0x00000000;
    GET_RCP_REG(SP_STATUS_REG)   &= ~SP_STATUS_DMA_BUSY;
    return;
}

/*** Scalar, Coprocessor Operations (vector unit) ***/

u16 rwR_VCE(void)
{ /* never saw a game try to read VCE out to a scalar GPR yet */
    register u16 ret_slot;

    ret_slot = 0x00 | (u16)get_VCE();
    return (ret_slot);
}
void rwW_VCE(u16 VCE)
{ /* never saw a game try to write VCE using a scalar GPR yet */
    register int i;

    VCE = 0x00 | (VCE & 0xFF);
    for (i = 0; i < 8; i++)
        cf_vce[i] = (VCE >> i) & 1;
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
    SR[0] = 0x00000000;
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
    SR[0] = 0x00000000;
    return;
}
void CTC2(unsigned int rt, unsigned int rd)
{
    W_VCF[rd & 3](SR[rt] & 0x0000FFFF);
    return;
}

/*** Scalar, Coprocessor Operations (vector unit, scalar cache transfers) ***/

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
    register u32 addr;
    int correction;
    const unsigned int e = element;

    if (e & 0x1)
    {
        message("LSV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 2*offset) & 0x00000FFF;
    correction = addr % 0x004;
    if (correction == 0x003)
    {
        message("LSV\nWeird addr.");
        return;
    }
    VR_S(vt, e) = *(pi16)(DMEM + addr - HES(0x000)*(correction - 1));
    return;
}
void LLV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    int correction;
    const unsigned int e = element;

    if (e & 0x1)
    {
        message("LLV\nOdd element.");
        return;
    } /* Illegal (but still even) elements are used by Boss Game Studios. */
    addr = (SR[base] + 4*offset) & 0x00000FFF;
    if (addr & 0x00000001)
    { /* branch very unlikely:  "Star Wars:  Battle for Naboo" unaligned addr */
        VR_A(vt, e+0x0) = DMEM[BES(addr)];
        addr = (addr + 0x00000001) & 0x00000FFF;
        VR_U(vt, e+0x1) = DMEM[BES(addr)];
        addr = (addr + 0x00000001) & 0x00000FFF;
        VR_A(vt, e+0x2) = DMEM[BES(addr)];
        addr = (addr + 0x00000001) & 0x00000FFF;
        VR_U(vt, e+0x3) = DMEM[BES(addr)];
        return;
    }
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

    if (e & 0x1)
    {
        message("LDV\nOdd element.");
        return;
    } /* Illegal (but still even) elements are used by Boss Game Studios. */
    addr = (SR[base] + 8*offset) & 0x00000FFF;
    switch (addr & 07)
    {
        case 00:
            VR_S(vt, e+0x0) = *(pi16)(DMEM + addr + HES(0x000));
            VR_S(vt, e+0x2) = *(pi16)(DMEM + addr + HES(0x002));
            VR_S(vt, e+0x4) = *(pi16)(DMEM + addr + HES(0x004));
            VR_S(vt, e+0x6) = *(pi16)(DMEM + addr + HES(0x006));
            return;
        case 01: /* standard ABI ucodes (unlike e.g. MusyX w/ even addresses) */
            VR_S(vt, e+0x0) = *(pi16)(DMEM + addr + 0x000);
            VR_A(vt, e+0x2) = DMEM[addr + 0x002 - BES(0x000)];
            VR_U(vt, e+0x3) = DMEM[addr + 0x003 + BES(0x000)];
            VR_S(vt, e+0x4) = *(pi16)(DMEM + addr + 0x004);
            VR_A(vt, e+0x6) = DMEM[addr + 0x006 - BES(0x000)];
            addr += 0x007 + BES(00);
            addr &= 0x00000FFF;
            VR_U(vt, e+0x7) = DMEM[addr];
            return;
        case 02:
            VR_S(vt, e+0x0) = *(pi16)(DMEM + addr + 0x000 - HES(0x000));
            VR_S(vt, e+0x2) = *(pi16)(DMEM + addr + 0x002 + HES(0x000));
            VR_S(vt, e+0x4) = *(pi16)(DMEM + addr + 0x004 - HES(0x000));
            addr += 0x006 + HES(00);
            addr &= 0x00000FFF;
            VR_S(vt, e+0x6) = *(pi16)(DMEM + addr);
            return;
        case 03: /* standard ABI ucodes (unlike e.g. MusyX w/ even addresses) */
            VR_A(vt, e+0x0) = DMEM[addr + 0x000 - BES(0x000)];
            VR_U(vt, e+0x1) = DMEM[addr + 0x001 + BES(0x000)];
            VR_S(vt, e+0x2) = *(pi16)(DMEM + addr + 0x002);
            VR_A(vt, e+0x4) = DMEM[addr + 0x004 - BES(0x000)];
            addr += 0x005 + BES(00);
            addr &= 0x00000FFF;
            VR_U(vt, e+0x5) = DMEM[addr];
            VR_S(vt, e+0x6) = *(pi16)(DMEM + addr + 0x001 - BES(0x000));
            return;
        case 04:
            VR_S(vt, e+0x0) = *(pi16)(DMEM + addr + HES(0x000));
            VR_S(vt, e+0x2) = *(pi16)(DMEM + addr + HES(0x002));
            addr += 0x004 + WES(00);
            addr &= 0x00000FFF;
            VR_S(vt, e+0x4) = *(pi16)(DMEM + addr + HES(0x000));
            VR_S(vt, e+0x6) = *(pi16)(DMEM + addr + HES(0x002));
            return;
        case 05: /* standard ABI ucodes (unlike e.g. MusyX w/ even addresses) */
            VR_S(vt, e+0x0) = *(pi16)(DMEM + addr + 0x000);
            VR_A(vt, e+0x2) = DMEM[addr + 0x002 - BES(0x000)];
            addr += 0x003;
            addr &= 0x00000FFF;
            VR_U(vt, e+0x3) = DMEM[addr + BES(0x000)];
            VR_S(vt, e+0x4) = *(pi16)(DMEM + addr + 0x001);
            VR_A(vt, e+0x6) = DMEM[addr + BES(0x003)];
            VR_U(vt, e+0x7) = DMEM[addr + BES(0x004)];
            return;
        case 06:
            VR_S(vt, e+0x0) = *(pi16)(DMEM + addr - HES(0x000));
            addr += 0x002;
            addr &= 0x00000FFF;
            VR_S(vt, e+0x2) = *(pi16)(DMEM + addr + HES(0x000));
            VR_S(vt, e+0x4) = *(pi16)(DMEM + addr + HES(0x002));
            VR_S(vt, e+0x6) = *(pi16)(DMEM + addr + HES(0x004));
            return;
        case 07: /* standard ABI ucodes (unlike e.g. MusyX w/ even addresses) */
            VR_A(vt, e+0x0) = DMEM[addr - BES(0x000)];
            addr += 0x001;
            addr &= 0x00000FFF;
            VR_U(vt, e+0x1) = DMEM[addr + BES(0x000)];
            VR_S(vt, e+0x2) = *(pi16)(DMEM + addr + 0x001);
            VR_A(vt, e+0x4) = DMEM[addr + BES(0x003)];
            VR_U(vt, e+0x5) = DMEM[addr + BES(0x004)];
            VR_S(vt, e+0x6) = *(pi16)(DMEM + addr + 0x005);
            return;
    }
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
    register u32 addr;
    int correction;
    const unsigned int e = element;

    if ((e & 0x1) || e > 0xC) /* must support illegal even elements in F3DEX2 */
    {
        message("SLV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 4*offset) & 0x00000FFF;
    if (addr & 0x00000001)
    {
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
    if (e > 0x8 || (e & 0x1))
    { /* Illegal elements with Boss Game Studios publications. */
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
    }
    switch (addr & 07)
    {
        case 00:
            *(pi16)(DMEM + addr + HES(0x000)) = VR_S(vt, e+0x0);
            *(pi16)(DMEM + addr + HES(0x002)) = VR_S(vt, e+0x2);
            *(pi16)(DMEM + addr + HES(0x004)) = VR_S(vt, e+0x4);
            *(pi16)(DMEM + addr + HES(0x006)) = VR_S(vt, e+0x6);
            return;
        case 01: /* "Tetrisphere" audio ucode */
            *(pi16)(DMEM + addr + 0x000) = VR_S(vt, e+0x0);
            DMEM[addr + 0x002 - BES(0x000)] = VR_A(vt, e+0x2);
            DMEM[addr + 0x003 + BES(0x000)] = VR_U(vt, e+0x3);
            *(pi16)(DMEM + addr + 0x004) = VR_S(vt, e+0x4);
            DMEM[addr + 0x006 - BES(0x000)] = VR_A(vt, e+0x6);
            addr += 0x007 + BES(0x000);
            addr &= 0x00000FFF;
            DMEM[addr] = VR_U(vt, e+0x7);
            return;
        case 02:
            *(pi16)(DMEM + addr + 0x000 - HES(0x000)) = VR_S(vt, e+0x0);
            *(pi16)(DMEM + addr + 0x002 + HES(0x000)) = VR_S(vt, e+0x2);
            *(pi16)(DMEM + addr + 0x004 - HES(0x000)) = VR_S(vt, e+0x4);
            addr += 0x006 + HES(0x000);
            addr &= 0x00000FFF;
            *(pi16)(DMEM + addr) = VR_S(vt, e+0x6);
            return;
        case 03: /* "Tetrisphere" audio ucode */
            DMEM[addr + 0x000 - BES(0x000)] = VR_A(vt, e+0x0);
            DMEM[addr + 0x001 + BES(0x000)] = VR_U(vt, e+0x1);
            *(pi16)(DMEM + addr + 0x002) = VR_S(vt, e+0x2);
            DMEM[addr + 0x004 - BES(0x000)] = VR_A(vt, e+0x4);
            addr += 0x005 + BES(0x000);
            addr &= 0x00000FFF;
            DMEM[addr] = VR_U(vt, e+0x5);
            *(pi16)(DMEM + addr + 0x001 - BES(0x000)) = VR_S(vt, 0x6);
            return;
        case 04:
            *(pi16)(DMEM + addr + HES(0x000)) = VR_S(vt, e+0x0);
            *(pi16)(DMEM + addr + HES(0x002)) = VR_S(vt, e+0x2);
            addr = (addr + 0x004) & 0x00000FFF;
            *(pi16)(DMEM + addr + HES(0x000)) = VR_S(vt, e+0x4);
            *(pi16)(DMEM + addr + HES(0x002)) = VR_S(vt, e+0x6);
            return;
        case 05: /* "Tetrisphere" audio ucode */
            *(pi16)(DMEM + addr + 0x000) = VR_S(vt, e+0x0);
            DMEM[addr + 0x002 - BES(0x000)] = VR_A(vt, e+0x2);
            addr = (addr + 0x003) & 0x00000FFF;
            DMEM[addr + BES(0x000)] = VR_U(vt, e+0x3);
            *(pi16)(DMEM + addr + 0x001) = VR_S(vt, e+0x4);
            DMEM[addr + BES(0x003)] = VR_A(vt, e+0x6);
            DMEM[addr + BES(0x004)] = VR_U(vt, e+0x7);
            return;
        case 06:
            *(pi16)(DMEM + addr - HES(0x000)) = VR_S(vt, e+0x0);
            addr = (addr + 0x002) & 0x00000FFF;
            *(pi16)(DMEM + addr + HES(0x000)) = VR_S(vt, e+0x2);
            *(pi16)(DMEM + addr + HES(0x002)) = VR_S(vt, e+0x4);
            *(pi16)(DMEM + addr + HES(0x004)) = VR_S(vt, e+0x6);
            return;
        case 07: /* "Tetrisphere" audio ucode */
            DMEM[addr - BES(0x000)] = VR_A(vt, e+0x0);
            addr = (addr + 0x001) & 0x00000FFF;
            DMEM[addr + BES(0x000)] = VR_U(vt, e+0x1);
            *(pi16)(DMEM + addr + 0x001) = VR_S(vt, e+0x2);
            DMEM[addr + BES(0x003)] = VR_A(vt, e+0x4);
            DMEM[addr + BES(0x004)] = VR_U(vt, e+0x5);
            *(pi16)(DMEM + addr + 0x005) = VR_S(vt, e+0x6);
            return;
    }
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

    if (e != 0x0)
    {
        message("LPV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 8*offset) & 0x00000FFF;
    b = addr & 07;
    addr &= ~07;
    switch (b)
    {
        case 00:
            VR[vt][07] = DMEM[addr + BES(0x007)] << 8;
            VR[vt][06] = DMEM[addr + BES(0x006)] << 8;
            VR[vt][05] = DMEM[addr + BES(0x005)] << 8;
            VR[vt][04] = DMEM[addr + BES(0x004)] << 8;
            VR[vt][03] = DMEM[addr + BES(0x003)] << 8;
            VR[vt][02] = DMEM[addr + BES(0x002)] << 8;
            VR[vt][01] = DMEM[addr + BES(0x001)] << 8;
            VR[vt][00] = DMEM[addr + BES(0x000)] << 8;
            return;
        case 01: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CFB layer */
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
            return;
        case 02: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CFB layer */
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
            return;
        case 03: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CFB layer */
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
            return;
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
            return;
        case 05: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CFB layer */
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
            return;
        case 06: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CFB layer */
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
            return;
        case 07: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CFB layer */
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
            return;
    }
}
void LUV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register unsigned int b;
    const unsigned int e = element;

    addr = (SR[base] + 8*offset) & 0x00000FFF;
    if (e != 0x0)
    { /* "Mia Hamm Soccer 64" SP exception override (zilmar) */
        addr += (~e + 0x1) & 0xF;
        for (b = 0; b < 8; b++)
        {
            VR[vt][b] = DMEM[BES(addr &= 0x00000FFF)] << 7;
            addr -= 16 * (e - b - 1 == 0x0);
            ++addr;
        }
        return;
    }
    b = addr & 07;
    addr &= ~07;
    switch (b)
    {
        case 00:
            VR[vt][07] = DMEM[addr + BES(0x007)] << 7;
            VR[vt][06] = DMEM[addr + BES(0x006)] << 7;
            VR[vt][05] = DMEM[addr + BES(0x005)] << 7;
            VR[vt][04] = DMEM[addr + BES(0x004)] << 7;
            VR[vt][03] = DMEM[addr + BES(0x003)] << 7;
            VR[vt][02] = DMEM[addr + BES(0x002)] << 7;
            VR[vt][01] = DMEM[addr + BES(0x001)] << 7;
            VR[vt][00] = DMEM[addr + BES(0x000)] << 7;
            return;
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
            return;
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
            return;
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
            return;
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
            return;
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
            return;
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
            return;
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
            return;
    }
}
void SPV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register unsigned int b;
    const unsigned int e = element;

    if (e != 0x0)
    {
        message("SPV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 8*offset) & 0x00000FFF;
    b = addr & 07;
    addr &= ~07;
    switch (b)
    {
        case 00:
            DMEM[addr + BES(0x007)] = (u8)(VR[vt][07] >> 8);
            DMEM[addr + BES(0x006)] = (u8)(VR[vt][06] >> 8);
            DMEM[addr + BES(0x005)] = (u8)(VR[vt][05] >> 8);
            DMEM[addr + BES(0x004)] = (u8)(VR[vt][04] >> 8);
            DMEM[addr + BES(0x003)] = (u8)(VR[vt][03] >> 8);
            DMEM[addr + BES(0x002)] = (u8)(VR[vt][02] >> 8);
            DMEM[addr + BES(0x001)] = (u8)(VR[vt][01] >> 8);
            DMEM[addr + BES(0x000)] = (u8)(VR[vt][00] >> 8);
            return;
        case 01: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CFB layer */
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
            return;
        case 02: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CFB layer */
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
            return;
        case 03: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CFB layer */
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
            return;
        case 04: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CFB layer */
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
            return;
        case 05: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CFB layer */
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
            return;
        case 06: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CFB layer */
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
            return;
        case 07: /* F3DZEX 2.08J "Doubutsu no Mori" (Animal Forest) CFB layer */
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
            return;
    }
}
void SUV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register unsigned int b;
    const unsigned int e = element;

    if (e != 0x0)
    {
        message("SUV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 8*offset) & 0x00000FFF;
    b = addr & 07;
    addr &= ~07;
    switch (b)
    {
        case 00:
            DMEM[addr + BES(0x007)] = (u8)(VR[vt][07] >> 7);
            DMEM[addr + BES(0x006)] = (u8)(VR[vt][06] >> 7);
            DMEM[addr + BES(0x005)] = (u8)(VR[vt][05] >> 7);
            DMEM[addr + BES(0x004)] = (u8)(VR[vt][04] >> 7);
            DMEM[addr + BES(0x003)] = (u8)(VR[vt][03] >> 7);
            DMEM[addr + BES(0x002)] = (u8)(VR[vt][02] >> 7);
            DMEM[addr + BES(0x001)] = (u8)(VR[vt][01] >> 7);
            DMEM[addr + BES(0x000)] = (u8)(VR[vt][00] >> 7);
            return;
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
            return;
        default: /* Completely legal, just never seen it be done. */
            message("SUV\nWeird addr.");
            return;
    }
}

/*
 * Group III vector loads and stores:
 * HV, FV, and AV (As of RCP implementation, AV opcodes are reserved.)
 */
void LHV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    const unsigned int e = element;

    if (e != 0x0)
    {
        message("LHV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (addr & 0x0000000E)
    {
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

    if (e != 0x0)
    {
        message("SHV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (addr & 0x0000000E)
    {
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
    switch (e)
    {
        case 0x0:
            DMEM[addr + 0x000] = (u8)(VR[vt][00] >> 7);
            DMEM[addr + 0x004] = (u8)(VR[vt][01] >> 7);
            DMEM[addr + 0x008] = (u8)(VR[vt][02] >> 7);
            DMEM[addr + 0x00C] = (u8)(VR[vt][03] >> 7);
            return;
        case 0x8:
            DMEM[addr + 0x000] = (u8)(VR[vt][04] >> 7);
            DMEM[addr + 0x004] = (u8)(VR[vt][05] >> 7);
            DMEM[addr + 0x008] = (u8)(VR[vt][06] >> 7);
            DMEM[addr + 0x00C] = (u8)(VR[vt][07] >> 7);
            return;
        default:
            message("SFV\nIllegal element.");
            return;
    }
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

    if (e & 0x1)
    {
        message("LQV\nOdd element.");
        return;
    }
    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (addr & 0x00000001)
    {
        message("LQV\nOdd addr.");
        return;
    }
    b = addr & 0x0000000F;
    addr &= ~0x0000000F;
    switch (b/2) /* mistake in SGI patent regarding LQV */
    {
        case 0x0/2:
            VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x000));
            VR_S(vt,e+0x2) = *(pi16)(DMEM + addr + HES(0x002));
            VR_S(vt,e+0x4) = *(pi16)(DMEM + addr + HES(0x004));
            VR_S(vt,e+0x6) = *(pi16)(DMEM + addr + HES(0x006));
            VR_S(vt,e+0x8) = *(pi16)(DMEM + addr + HES(0x008));
            VR_S(vt,e+0xA) = *(pi16)(DMEM + addr + HES(0x00A));
            VR_S(vt,e+0xC) = *(pi16)(DMEM + addr + HES(0x00C));
            VR_S(vt,e+0xE) = *(pi16)(DMEM + addr + HES(0x00E));
            return;
        case 0x2/2:
            VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x002));
            VR_S(vt,e+0x2) = *(pi16)(DMEM + addr + HES(0x004));
            VR_S(vt,e+0x4) = *(pi16)(DMEM + addr + HES(0x006));
            VR_S(vt,e+0x6) = *(pi16)(DMEM + addr + HES(0x008));
            VR_S(vt,e+0x8) = *(pi16)(DMEM + addr + HES(0x00A));
            VR_S(vt,e+0xA) = *(pi16)(DMEM + addr + HES(0x00C));
            VR_S(vt,e+0xC) = *(pi16)(DMEM + addr + HES(0x00E));
            return;
        case 0x4/2:
            VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x004));
            VR_S(vt,e+0x2) = *(pi16)(DMEM + addr + HES(0x006));
            VR_S(vt,e+0x4) = *(pi16)(DMEM + addr + HES(0x008));
            VR_S(vt,e+0x6) = *(pi16)(DMEM + addr + HES(0x00A));
            VR_S(vt,e+0x8) = *(pi16)(DMEM + addr + HES(0x00C));
            VR_S(vt,e+0xA) = *(pi16)(DMEM + addr + HES(0x00E));
            return;
        case 0x6/2:
            VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x006));
            VR_S(vt,e+0x2) = *(pi16)(DMEM + addr + HES(0x008));
            VR_S(vt,e+0x4) = *(pi16)(DMEM + addr + HES(0x00A));
            VR_S(vt,e+0x6) = *(pi16)(DMEM + addr + HES(0x00C));
            VR_S(vt,e+0x8) = *(pi16)(DMEM + addr + HES(0x00E));
            return;
        case 0x8/2: /* "Resident Evil 2" cinematics and Boss Game Studios */
            VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x008));
            VR_S(vt,e+0x2) = *(pi16)(DMEM + addr + HES(0x00A));
            VR_S(vt,e+0x4) = *(pi16)(DMEM + addr + HES(0x00C));
            VR_S(vt,e+0x6) = *(pi16)(DMEM + addr + HES(0x00E));
            return;
        case 0xA/2: /* "Conker's Bad Fur Day" audio microcode by Rareware */
            VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x00A));
            VR_S(vt,e+0x2) = *(pi16)(DMEM + addr + HES(0x00C));
            VR_S(vt,e+0x4) = *(pi16)(DMEM + addr + HES(0x00E));
            return;
        case 0xC/2: /* "Conker's Bad Fur Day" audio microcode by Rareware */
            VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x00C));
            VR_S(vt,e+0x2) = *(pi16)(DMEM + addr + HES(0x00E));
            return;
        case 0xE/2: /* "Conker's Bad Fur Day" audio microcode by Rareware */
            VR_S(vt,e+0x0) = *(pi16)(DMEM + addr + HES(0x00E));
            return;
    }
}
void LRV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register unsigned int b;
    const unsigned int e = element;

    if (e != 0x0)
    {
        message("LRV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (addr & 0x00000001)
    {
        message("LRV\nOdd addr.");
        return;
    }
    b = addr & 0x0000000F;
    addr &= ~0x0000000F;
    switch (b/2)
    {
        case 0xE/2:
            VR[vt][01] = *(pi16)(DMEM + addr + HES(0x000));
            VR[vt][02] = *(pi16)(DMEM + addr + HES(0x002));
            VR[vt][03] = *(pi16)(DMEM + addr + HES(0x004));
            VR[vt][04] = *(pi16)(DMEM + addr + HES(0x006));
            VR[vt][05] = *(pi16)(DMEM + addr + HES(0x008));
            VR[vt][06] = *(pi16)(DMEM + addr + HES(0x00A));
            VR[vt][07] = *(pi16)(DMEM + addr + HES(0x00C));
            return;
        case 0xC/2:
            VR[vt][02] = *(pi16)(DMEM + addr + HES(0x000));
            VR[vt][03] = *(pi16)(DMEM + addr + HES(0x002));
            VR[vt][04] = *(pi16)(DMEM + addr + HES(0x004));
            VR[vt][05] = *(pi16)(DMEM + addr + HES(0x006));
            VR[vt][06] = *(pi16)(DMEM + addr + HES(0x008));
            VR[vt][07] = *(pi16)(DMEM + addr + HES(0x00A));
            return;
        case 0xA/2:
            VR[vt][03] = *(pi16)(DMEM + addr + HES(0x000));
            VR[vt][04] = *(pi16)(DMEM + addr + HES(0x002));
            VR[vt][05] = *(pi16)(DMEM + addr + HES(0x004));
            VR[vt][06] = *(pi16)(DMEM + addr + HES(0x006));
            VR[vt][07] = *(pi16)(DMEM + addr + HES(0x008));
            return;
        case 0x8/2:
            VR[vt][04] = *(pi16)(DMEM + addr + HES(0x000));
            VR[vt][05] = *(pi16)(DMEM + addr + HES(0x002));
            VR[vt][06] = *(pi16)(DMEM + addr + HES(0x004));
            VR[vt][07] = *(pi16)(DMEM + addr + HES(0x006));
            return;
        case 0x6/2:
            VR[vt][05] = *(pi16)(DMEM + addr + HES(0x000));
            VR[vt][06] = *(pi16)(DMEM + addr + HES(0x002));
            VR[vt][07] = *(pi16)(DMEM + addr + HES(0x004));
            return;
        case 0x4/2:
            VR[vt][06] = *(pi16)(DMEM + addr + HES(0x000));
            VR[vt][07] = *(pi16)(DMEM + addr + HES(0x002));
            return;
        case 0x2/2:
            VR[vt][07] = *(pi16)(DMEM + addr + HES(0x000));
            return;
        case 0x0/2:
            return;
    }
}
void SQV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register unsigned int b;
    const unsigned int e = element;

    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (e != 0x0)
    { /* illegal SQV, happens with "Mia Hamm Soccer 64" */
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
    }
    b = addr & 0x0000000F;
    addr &= ~0x0000000F;
    switch (b)
    {
        case 00:
            *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][00];
            *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][01];
            *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][02];
            *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][03];
            *(pi16)(DMEM + addr + HES(0x008)) = VR[vt][04];
            *(pi16)(DMEM + addr + HES(0x00A)) = VR[vt][05];
            *(pi16)(DMEM + addr + HES(0x00C)) = VR[vt][06];
            *(pi16)(DMEM + addr + HES(0x00E)) = VR[vt][07];
            return;
        case 02:
            *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][00];
            *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][01];
            *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][02];
            *(pi16)(DMEM + addr + HES(0x008)) = VR[vt][03];
            *(pi16)(DMEM + addr + HES(0x00A)) = VR[vt][04];
            *(pi16)(DMEM + addr + HES(0x00C)) = VR[vt][05];
            *(pi16)(DMEM + addr + HES(0x00E)) = VR[vt][06];
            return;
        case 04:
            *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][00];
            *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][01];
            *(pi16)(DMEM + addr + HES(0x008)) = VR[vt][02];
            *(pi16)(DMEM + addr + HES(0x00A)) = VR[vt][03];
            *(pi16)(DMEM + addr + HES(0x00C)) = VR[vt][04];
            *(pi16)(DMEM + addr + HES(0x00E)) = VR[vt][05];
            return;
        case 06:
            *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][00];
            *(pi16)(DMEM + addr + HES(0x008)) = VR[vt][01];
            *(pi16)(DMEM + addr + HES(0x00A)) = VR[vt][02];
            *(pi16)(DMEM + addr + HES(0x00C)) = VR[vt][03];
            *(pi16)(DMEM + addr + HES(0x00E)) = VR[vt][04];
            return;
        default:
            message("SQV\nWeird addr.");
            return;
    }
}
void SRV(unsigned vt, unsigned element, signed offset, unsigned base)
{
    register u32 addr;
    register unsigned int b;
    const unsigned int e = element;

    if (e != 0x0)
    {
        message("SRV\nIllegal element.");
        return;
    }
    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (addr & 0x00000001)
    {
        message("SRV\nOdd addr.");
        return;
    }
    b = addr & 0x0000000F;
    addr &= ~0x0000000F;
    switch (b/2)
    {
        case 0xE/2:
            *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][01];
            *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][02];
            *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][03];
            *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][04];
            *(pi16)(DMEM + addr + HES(0x008)) = VR[vt][05];
            *(pi16)(DMEM + addr + HES(0x00A)) = VR[vt][06];
            *(pi16)(DMEM + addr + HES(0x00C)) = VR[vt][07];
            return;
        case 0xC/2:
            *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][02];
            *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][03];
            *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][04];
            *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][05];
            *(pi16)(DMEM + addr + HES(0x008)) = VR[vt][06];
            *(pi16)(DMEM + addr + HES(0x00A)) = VR[vt][07];
            return;
        case 0xA/2:
            *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][03];
            *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][04];
            *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][05];
            *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][06];
            *(pi16)(DMEM + addr + HES(0x008)) = VR[vt][07];
            return;
        case 0x8/2:
            *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][04];
            *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][05];
            *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][06];
            *(pi16)(DMEM + addr + HES(0x006)) = VR[vt][07];
            return;
        case 0x6/2:
            *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][05];
            *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][06];
            *(pi16)(DMEM + addr + HES(0x004)) = VR[vt][07];
            return;
        case 0x4/2:
            *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][06];
            *(pi16)(DMEM + addr + HES(0x002)) = VR[vt][07];
            return;
        case 0x2/2:
            *(pi16)(DMEM + addr + HES(0x000)) = VR[vt][07];
            return;
        case 0x0/2:
            return;
    }
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

    if (e & 1)
    {
        message("LTV\nIllegal element.");
        return;
    }
    if (vt & 07)
    {
        message("LTV\nUncertain case!");
        return; /* For LTV I am not sure; for STV I have an idea. */
    }
    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (addr & 0x0000000F)
    {
        message("LTV\nIllegal addr.");
        return;
    }
    for (i = 0; i < 8; i++) /* SGI screwed LTV up on N64.  See STV instead. */
        VR[vt+i][(i - e/2) & 07] = *(pi16)(DMEM + addr + HES(2*i));
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

    if (e & 1)
    {
        message("STV\nIllegal element.");
        return;
    }
    if (vt & 07)
    {
        message("STV\nUncertain case!");
        return; /* vt &= 030; */
    }
    addr = (SR[base] + 16*offset) & 0x00000FFF;
    if (addr & 0x0000000F)
    {
        message("STV\nIllegal addr.");
        return;
    }
    for (i = 0; i < 8; i++)
        *(pi16)(DMEM + addr + HES(2*i)) = VR[vt + (e/2 + i)%8][i];
    return;
}

/*** Modern pseudo-operations (not real instructions, but nice shortcuts) ***/
void ULW(unsigned int rd, u32 addr)
{ /* "Unaligned Load Word" */
    if (addr & 0x00000001)
    {
        SR_temp.B[03] = DMEM[BES(addr)];
        addr = (addr + 0x001) & 0xFFF;
        SR_temp.B[02] = DMEM[BES(addr)];
        addr = (addr + 0x001) & 0xFFF;
        SR_temp.B[01] = DMEM[BES(addr)];
        addr = (addr + 0x001) & 0xFFF;
        SR_temp.B[00] = DMEM[BES(addr)];
    }
    else /* addr & 0x00000002 */
    {
        SR_temp.H[01] = *(pi16)(DMEM + addr - HES(0x000));
        addr = (addr + 0x002) & 0xFFF;
        SR_temp.H[00] = *(pi16)(DMEM + addr + HES(0x000));
    }
    SR[rd] = SR_temp.W;
 /* SR[0] = 0x00000000; */
    return;
}
void USW(unsigned int rs, u32 addr)
{ /* "Unaligned Store Word" */
    SR_temp.W = SR[rs];
    if (addr & 0x00000001)
    {
        DMEM[BES(addr)] = SR_temp.B[03];
        addr = (addr + 0x001) & 0xFFF;
        DMEM[BES(addr)] = SR_temp.B[02];
        addr = (addr + 0x001) & 0xFFF;
        DMEM[BES(addr)] = SR_temp.B[01];
        addr = (addr + 0x001) & 0xFFF;
        DMEM[BES(addr)] = SR_temp.B[00];
    }
    else /* addr & 0x00000002 */
    {
        *(pi16)(DMEM + addr - HES(0x000)) = SR_temp.H[01];
        addr = (addr + 0x002) & 0xFFF;
        *(pi16)(DMEM + addr + HES(0x000)) = SR_temp.H[00];
    }
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

NOINLINE void run_task(void)
{
    register unsigned int PC;
    register unsigned int i;

#ifdef WAIT_FOR_CPU_HOST
    for (i = 0; i < 32; i++)
        MFC0_count[i] = 0;
#endif
    PC = FIT_IMEM(GET_RCP_REG(SP_PC_REG));
    CPU_running = ~GET_RCP_REG(SP_STATUS_REG) & SP_STATUS_HALT;

#ifdef _DEBUG
    while ((GET_RCP_REG(SP_STATUS_REG) & SP_STATUS_HALT) == 0)
#else
    while (CPU_running != 0)
#endif
    {
        p_vector_func vector_op;
#ifdef ARCH_MIN_SSE2
        v16 source, target;
#else
        ALIGNED i16 source[N], target[N];
#endif
        unsigned int op, element;

        inst = *(pi32)(IMEM + FIT_IMEM(PC));
#ifdef EMULATE_STATIC_PC
        PC = (PC + 0x004);
EX:
#endif
#ifdef SP_EXECUTE_LOG
        step_SP_commands(inst);
#endif

        op = inst >> 26;
#ifdef _DEBUG
        SR[0] = 0x00000000; /* already handled on per-instruction basis */
#endif
        switch (op)
        {
            s16 offset;
            unsigned int rd, vd;
            unsigned int rs, vs;
            unsigned int rt, vt;
            unsigned int base; /* a synonym of `rs' for memory load/store ops */
            register u32 addr;

        case 000: /* SPECIAL */
            rd = (inst & 0x0000FFFF) >> 11;
            rt = (inst >> 16) & 31;
            switch (inst % 64)
            {
            case 000: /* SLL */
                SR[rd] = SR[rt] << MASK_SA(inst >> 6);
                SR[0] = 0x00000000;
                CONTINUE;
            case 002: /* SRL */
                SR[rd] = (u32)(SR[rt]) >> MASK_SA(inst >> 6);
                SR[0] = 0x00000000;
                CONTINUE;
            case 003: /* SRA */
                SR[rd] = (s32)(SR[rt]) >> MASK_SA(inst >> 6);
                SR[0] = 0x00000000;
                CONTINUE;
            case 004: /* SLLV */
                rs = SPECIAL_DECODE_RS(inst);
                SR[rd] = SR[rt] << MASK_SA(SR[rs]);
                SR[0] = 0x00000000;
                CONTINUE;
            case 006: /* SRLV */
                rs = SPECIAL_DECODE_RS(inst);
                SR[rd] = (u32)(SR[rt]) >> MASK_SA(SR[rs]);
                SR[0] = 0x00000000;
                CONTINUE;
            case 007: /* SRAV */
                rs = SPECIAL_DECODE_RS(inst);
                SR[rd] = (s32)(SR[rt]) >> MASK_SA(SR[rs]);
                SR[0] = 0x00000000;
                CONTINUE;
            case 011: /* JALR */
                SR[rd] = (PC + LINK_OFF) & 0x00000FFC;
                SR[0] = 0x00000000;
            case 010: /* JR */
                rs = SPECIAL_DECODE_RS(inst);
                set_PC(SR[rs]);
                JUMP;
            case 015: /* BREAK */
                *CR[0x4] |= SP_STATUS_BROKE | SP_STATUS_HALT;
                CPU_running = 0;
                if (*CR[0x4] & SP_STATUS_INTR_BREAK)
                { /* SP_STATUS_INTR_BREAK */
                    GET_RCP_REG(MI_INTR_REG) |= 0x00000001;
                    GET_RSP_INFO(CheckInterrupts)();
                }
                CONTINUE;
            case 040: /* ADD */
            case 041: /* ADDU */
                rs = SPECIAL_DECODE_RS(inst);
                SR[rd] = SR[rs] + SR[rt];
                SR[0] = 0x00000000; /* needed for Rareware ucodes */
                CONTINUE;
            case 042: /* SUB */
            case 043: /* SUBU */
                rs = SPECIAL_DECODE_RS(inst);
                SR[rd] = SR[rs] - SR[rt];
                SR[0] = 0x00000000;
                CONTINUE;
            case 044: /* AND */
                rs = SPECIAL_DECODE_RS(inst);
                SR[rd] = SR[rs] & SR[rt];
                SR[0] = 0x00000000; /* needed for Rareware ucodes */
                CONTINUE;
            case 045: /* OR */
                rs = SPECIAL_DECODE_RS(inst);
                SR[rd] = SR[rs] | SR[rt];
                SR[0] = 0x00000000;
                CONTINUE;
            case 046: /* XOR */
                rs = SPECIAL_DECODE_RS(inst);
                SR[rd] = SR[rs] ^ SR[rt];
                SR[0] = 0x00000000;
                CONTINUE;
            case 047: /* NOR */
                rs = SPECIAL_DECODE_RS(inst);
                SR[rd] = ~(SR[rs] | SR[rt]);
                SR[0] = 0x00000000;
                CONTINUE;
            case 052: /* SLT */
                rs = SPECIAL_DECODE_RS(inst);
                SR[rd] = ((s32)(SR[rs]) < (s32)(SR[rt]));
                SR[0] = 0x00000000;
                CONTINUE;
            case 053: /* SLTU */
                rs = SPECIAL_DECODE_RS(inst);
                SR[rd] = ((u32)(SR[rs]) < (u32)(SR[rt]));
                SR[0] = 0x00000000;
                CONTINUE;
            default:
                res_S();
                CONTINUE;
            }
        case 001: /* REGIMM */
            rs = (inst >> 21) & 31;
            switch (rt = (inst >> 16) & 31)
            {
            case 020: /* BLTZAL */
                SR[31] = (PC + LINK_OFF) & 0x00000FFC;
                /* fall through */
            case 000: /* BLTZ */
                if (!((s32)SR[rs] < 0))
                    CONTINUE;
                set_PC(PC + 4*inst + SLOT_OFF);
                JUMP;
            case 021: /* BGEZAL */
                SR[31] = (PC + LINK_OFF) & 0x00000FFC;
                /* fall through */
            case 001: /* BGEZ */
                if (!((s32)SR[rs] >= 0))
                    CONTINUE;
                set_PC(PC + 4*inst + SLOT_OFF);
                JUMP;
            default:
                res_S();
                CONTINUE;
            }
        case 003: /* JAL */
            SR[31] = (PC + LINK_OFF) & 0x00000FFC;
        case 002: /* J */
            set_PC(4*inst);
            JUMP;
        case 004: /* BEQ */
            rs = (inst >> 21) & 31;
            rt = (inst >> 16) & 31;
            if (!(SR[rs] == SR[rt]))
                CONTINUE;
            set_PC(PC + 4*inst + SLOT_OFF);
            JUMP;
        case 005: /* BNE */
            rs = (inst >> 21) & 31;
            rt = (inst >> 16) & 31;
            if (!(SR[rs] != SR[rt]))
                CONTINUE;
            set_PC(PC + 4*inst + SLOT_OFF);
            JUMP;
        case 006: /* BLEZ */
            rs = (inst >> 21) & 31;
            if (!((s32)SR[rs] <= 0x00000000))
                CONTINUE;
            set_PC(PC + 4*inst + SLOT_OFF);
            JUMP;
        case 007: /* BGTZ */
            rs = (inst >> 21) & 31;
            if (!((s32)SR[rs] >  0x00000000))
                CONTINUE;
            set_PC(PC + 4*inst + SLOT_OFF);
            JUMP;
        case 010: /* ADDI */
        case 011: /* ADDIU */
            rs = (inst >> 21) & 31;
            rt = (inst >> 16) & 31;
            SR[rt] = SR[rs] + (s16)(inst);
            SR[0] = 0x00000000;
            CONTINUE;
        case 012: /* SLTI */
            rs = (inst >> 21) & 31;
            rt = (inst >> 16) & 31;
            SR[rt] = ((s32)(SR[rs]) < (s16)(inst));
            SR[0] = 0x00000000;
            CONTINUE;
        case 013: /* SLTIU */
            rs = (inst >> 21) & 31;
            rt = (inst >> 16) & 31;
            SR[rt] = ((u32)(SR[rs]) < (u16)(inst));
            SR[0] = 0x00000000;
            CONTINUE;
        case 014: /* ANDI */
            rs = (inst >> 21) & 31;
            rt = (inst >> 16) & 31;
            SR[rt] = SR[rs] & (inst & 0x0000FFFF);
            SR[0] = 0x00000000;
            CONTINUE;
        case 015: /* ORI */
            rs = (inst >> 21) & 31;
            rt = (inst >> 16) & 31;
            SR[rt] = SR[rs] | (inst & 0x0000FFFF);
            SR[0] = 0x00000000;
            CONTINUE;
        case 016: /* XORI */
            rs = (inst >> 21) & 31;
            rt = (inst >> 16) & 31;
            SR[rt] = SR[rs] ^ (inst & 0x0000FFFF);
            SR[0] = 0x00000000;
            CONTINUE;
        case 017: /* LUI */
            rt = (inst >> 16) & 31;
            SR[rt] = inst << 16;
            SR[0] = 0x00000000;
            CONTINUE;
        case 020: /* COP0 */
            rd = (inst & 0x0000FFFF) >> 11;
            rt = (inst >> 16) & 31;
            switch (rs = (inst >> 21) & 31)
            {
            case 000: /* MFC0 */
                SP_CP0_MF(rt, rd & 0xF);
                CONTINUE;
            case 004: /* MTC0 */
                SP_CP0_MT[rd & 0xF](rt);
                CONTINUE;
            default:
                res_S();
                CONTINUE;
            }
        case 022: /* COP2 */
            op = inst & 0x0000003F;
            vd = (inst & 0x000007FF) >>  6; /* inst.R.sa */
            vs = (inst & 0x0000FFFF) >> 11; /* inst.R.rd */
            vt = (inst >> 16) & 31;

            rs = (inst >> 21) & 31;
            if (rs < 16)
                switch (rs)
                {
                case 000:
                    MFC2(vt, vs, vd >>= 1);
                    CONTINUE;
                case 002:
                    CFC2(vt, vs);
                    CONTINUE;
                case 004:
                    MTC2(vt, vs, vd >>= 1);
                    CONTINUE;
                case 006:
                    CTC2(vt, vs);
                    CONTINUE;
                default:
                    res_S();
                    CONTINUE;
                }
            vector_op = COP2_C2[op];
            element = rs & 0xFu;

            for (i = 0; i < N; i++)
                shuffle_temporary[i] = VR[vt][ei[element][i]];
#ifdef ARCH_MIN_SSE2
            source = *(v16 *)VR[vs];
            target = *(v16 *)shuffle_temporary;

            *(v16 *)(VR[vd]) = vector_op(source, target);
#else
            vector_copy(source, VR[vs]);
            vector_copy(target, shuffle_temporary);

            vector_op(source, target);
            vector_copy(VR[vd], V_result);
#endif
            CONTINUE;
        case 040: /* LB */
            offset = (s16)(inst);
            base = (inst >> 21) & 31;

            addr = (SR[base] + offset) & 0x00000FFF;
            rt = (inst >> 16) & 31;
            SR[rt] = DMEM[BES(addr)];
            SR[rt] = (s8)(SR[rt]);
            SR[0] = 0x00000000;
            CONTINUE;
        case 041: /* LH */
            offset = (s16)(inst);
            base = (inst >> 21) & 31;

            addr = (SR[base] + offset) & 0x00000FFF;
            rt = (inst >> 16) & 31;
            if (addr%0x004 == 0x003)
            {
                SR_B(rt, 2) = DMEM[addr - BES(0x000)];
                addr = (addr + 0x00000001) & 0x00000FFF;
                SR_B(rt, 3) = DMEM[addr + BES(0x000)];
                SR[rt] = (s16)(SR[rt]);
            }
            else
            {
                addr -= HES(0x000)*(addr%0x004 - 1);
                SR[rt] = *(ps16)(DMEM + addr);
            }
            SR[0] = 0x00000000;
            CONTINUE;
        case 043: /* LW */
            offset = (s16)(inst);
            base = (inst >> 21) & 31;

            addr = (SR[base] + offset) & 0x00000FFF;
            rt = (inst >> 16) & 31;
            if (addr%0x004 != 0x000)
                ULW(rt, addr);
            else
                SR[rt] = *(pi32)(DMEM + addr);
            SR[0] = 0x00000000;
            CONTINUE;
        case 044: /* LBU */
            offset = (s16)(inst);
            base = (inst >> 21) & 31;

            addr = (SR[base] + offset) & 0x00000FFF;
            rt = (inst >> 16) & 31;
            SR[rt] = DMEM[BES(addr)];
            SR[rt] = (u8)(SR[rt]);
            SR[0] = 0x00000000;
            CONTINUE;
        case 045: /* LHU */
            offset = (s16)(inst);
            base = (inst >> 21) & 31;

            addr = (SR[base] + offset) & 0x00000FFF;
            rt = (inst >> 16) & 31;
            if (addr%0x004 == 0x003)
            {
                SR_B(rt, 2) = DMEM[addr - BES(0x000)];
                addr = (addr + 0x00000001) & 0x00000FFF;
                SR_B(rt, 3) = DMEM[addr + BES(0x000)];
                SR[rt] = (u16)(SR[rt]);
            }
            else
            {
                addr -= HES(0x000)*(addr%0x004 - 1);
                SR[rt] = *(pu16)(DMEM + addr);
            }
            SR[0] = 0x00000000;
            CONTINUE;
        case 050: /* SB */
            offset = (s16)(inst);
            base = (inst >> 21) & 31;

            addr = (SR[base] + offset) & 0x00000FFF;
            rt = (inst >> 16) & 31;
            DMEM[BES(addr)] = (u8)(SR[rt]);
            CONTINUE;
        case 051: /* SH */
            offset = (s16)(inst);
            base = (inst >> 21) & 31;

            addr = (SR[base] + offset) & 0x00000FFF;
            rt = (inst >> 16) & 31;
            if (addr%0x004 == 0x003)
            {
                DMEM[addr - BES(0x000)] = SR_B(rt, 2);
                addr = (addr + 0x00000001) & 0x00000FFF;
                DMEM[addr + BES(0x000)] = SR_B(rt, 3);
                CONTINUE;
            }
            addr -= HES(0x000)*(addr%0x004 - 1);
            *(pi16)(DMEM + addr) = (i16)(SR[rt]);
            CONTINUE;
        case 053: /* SW */
            offset = (s16)(inst);
            base = (inst >> 21) & 31;

            addr = (SR[base] + offset) & 0x00000FFF;
            rt = (inst >> 16) & 31;
            if (addr%0x004 != 0x000)
                USW(rt, addr);
            else
                *(pi32)(DMEM + addr) = SR[rt];
            CONTINUE;
        case 062: /* LWC2 */
            vt = (inst >> 16) & 31;
            element = (inst & 0x000007FF) >> 7;
            offset = (s16)(inst);
#ifdef ARCH_MIN_SSE2
            offset <<= 5 + 4; /* safe on x86, skips 5-bit rd, 4-bit element */
            offset >>= 5 + 4;
#else
            offset = SE(offset, 6); /* sign-extended seven-bit offset */
#endif
            base = (inst >> 21) & 31;

            rd = (inst & 0x0000FFFF) >> 11;
            LWC2[rd](vt, element, offset, base);
            CONTINUE;
        case 072: /* SWC2 */
            vt = (inst >> 16) & 31;
            element = (inst & 0x000007FF) >> 7;
            offset = (s16)(inst);
#ifdef ARCH_MIN_SSE2
            offset <<= 5 + 4; /* safe on x86, skips 5-bit rd, 4-bit element */
            offset >>= 5 + 4;
#else
            offset = SE(offset, 6); /* sign-extended seven-bit offset */
#endif
            base = (inst >> 21) & 31;

            rd = (inst & 0x0000FFFF) >> 11;
            SWC2[rd](vt, element, offset, base);
            CONTINUE;
        default:
            res_S();
            CONTINUE;
        }
#ifndef EMULATE_STATIC_PC
        if (stage == 2) /* branch phase of scheduler */
        {
            stage = 0*stage;
            PC = temp_PC & 0x00000FFC;
            GET_RCP_REG(SP_PC_REG) = temp_PC;
        }
        else
        {
            stage = 2*stage; /* next IW in branch delay slot? */
            PC = (PC + 0x004) & 0xFFC;
            GET_RCP_REG(SP_PC_REG) = 0x04001000 + PC;
        }
        continue;
#else
        continue;
BRANCH:
        inst = *(pi32)(IMEM + FIT_IMEM(PC));
        PC = temp_PC & 0x00000FFC;
        goto EX;
#endif
    }
    GET_RCP_REG(SP_PC_REG) = 0x04001000 | FIT_IMEM(PC);

/*
 * An optional EMMS when compiling with Intel SIMD or MMX support.
 *
 * Whether or not MMX has been executed in this emulator, here is a good time
 * to finally empty the MM state, at the end of a long interpreter loop.
 */
#if defined (ARCH_MIN_SSE2) && !defined (__x86_64__)
    _mm_empty();
#endif

    if (*CR[0x4] & SP_STATUS_BROKE) /* normal exit, from executing BREAK */
        return;
    else if (GET_RCP_REG(MI_INTR_REG) & 1) /* interrupt set by MTC0 to break */
        GET_RSP_INFO(CheckInterrupts)();
    else if (*CR[0x7] != 0x00000000) /* semaphore lock fixes */
        {}
#ifdef WAIT_FOR_CPU_HOST
    else
        MF_SP_STATUS_TIMEOUT = 16; /* From now on, wait 16 times, not 32767. */
#else
    else /* ??? unknown, possibly external intervention from CPU memory map */
    {
        message("SP_SET_HALT");
        return;
    }
#endif
    *CR[0x4] &= ~SP_STATUS_HALT; /* CPU restarts with the correct SIGs. */
    CPU_running = 1;
    return;
}
