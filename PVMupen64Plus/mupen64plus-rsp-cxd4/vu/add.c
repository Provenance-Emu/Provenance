/******************************************************************************\
* Project:  MSP Simulation Layer for Vector Unit Computational Adds            *
* Authors:  Iconoclast                                                         *
* Release:  2016.03.23                                                         *
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

#include "add.h"

#ifdef ARCH_MIN_SSE2
static INLINE void SIGNED_CLAMP_ADD(pi16 VD, pi16 VS, pi16 VT)
{
    v16 dst, src, vco;
    v16 max, min;

    src = _mm_load_si128((v16 *)VS);
    dst = _mm_load_si128((v16 *)VT);
    vco = _mm_load_si128((v16 *)cf_co);

/*
 * Due to premature clamping in between adds, sometimes we need to add the
 * LESSER of two integers, either VS or VT, to the carry-in flag matching the
 * current vector register slice, BEFORE finally adding the greater integer.
 */
    max = _mm_max_epi16(dst, src);
    min = _mm_min_epi16(dst, src);

    min = _mm_adds_epi16(min, vco);
    max = _mm_adds_epi16(max, min);
    _mm_store_si128((v16 *)VD, max);
    return;
}
static INLINE void SIGNED_CLAMP_SUB(pi16 VD, pi16 VS, pi16 VT)
{
    v16 dst, src, vco;
    v16 dif, res, xmm;

    src = _mm_load_si128((v16 *)VS);
    dst = _mm_load_si128((v16 *)VT);
    vco = _mm_load_si128((v16 *)cf_co);

    res = _mm_subs_epi16(src, dst);

/*
 * Due to premature clamps in-between subtracting two of the three operands,
 * we must be careful not to offset the result accidentally when subtracting
 * the corresponding VCO flag AFTER the saturation from doing (VS - VT).
 */
    dif = _mm_add_epi16(res, vco);
    dif = _mm_xor_si128(dif, res); /* Adding one suddenly inverts the sign? */
    dif = _mm_and_si128(dif, dst); /* Sign change due to subtracting a neg. */
    xmm = _mm_sub_epi16(src, dst);
    src = _mm_andnot_si128(src, dif); /* VS must be >= 0x0000 for overflow. */
    xmm = _mm_and_si128(xmm, src); /* VS + VT != INT16_MIN; VS + VT >= +32768 */
    xmm = _mm_srli_epi16(xmm, 15); /* src = (INT16_MAX + 1 === INT16_MIN) ? */

    xmm = _mm_andnot_si128(xmm, vco); /* If it's NOT overflow, keep flag. */
    res = _mm_subs_epi16(res, xmm);
    _mm_store_si128((v16 *)VD, res);
    return;
}
#else
static INLINE void SIGNED_CLAMP_ADD(pi16 VD, pi16 VS, pi16 VT)
{
    i32 sum[N];
    i16 hi[N], lo[N];
    register int i;

    for (i = 0; i < N; i++)
        sum[i] = VS[i] + VT[i] + cf_co[i];
    for (i = 0; i < N; i++)
        lo[i] = (sum[i] + 0x8000) >> 31;
    for (i = 0; i < N; i++)
        hi[i] = (0x7FFF - sum[i]) >> 31;
    vector_copy(VD, VACC_L);
    for (i = 0; i < N; i++)
        VD[i] &= ~lo[i];
    for (i = 0; i < N; i++)
        VD[i] |=  hi[i];
    for (i = 0; i < N; i++)
        VD[i] ^= 0x8000 & (hi[i] | lo[i]);
    return;
}
static INLINE void SIGNED_CLAMP_SUB(pi16 VD, pi16 VS, pi16 VT)
{
    i32 dif[N];
    i16 hi[N], lo[N];
    register int i;

    for (i = 0; i < N; i++)
        dif[i] = VS[i] - VT[i] - cf_co[i];
    for (i = 0; i < N; i++)
        lo[i] = (dif[i] + 0x8000) >> 31;
    for (i = 0; i < N; i++)
        hi[i] = (0x7FFF - dif[i]) >> 31;
    vector_copy(VD, VACC_L);
    for (i = 0; i < N; i++)
        VD[i] &= ~lo[i];
    for (i = 0; i < N; i++)
        VD[i] |=  hi[i];
    for (i = 0; i < N; i++)
        VD[i] ^= 0x8000 & (hi[i] | lo[i]);
    return;
}
#endif

INLINE static void clr_ci(pi16 VD, pi16 VS, pi16 VT)
{ /* clear CARRY and carry in to accumulators */
    register int i;

    for (i = 0; i < N; i++)
        VACC_L[i] = VS[i] + VT[i] + cf_co[i];
    SIGNED_CLAMP_ADD(VD, VS, VT);

 /* CTC2    $0, $vco # zeroing RSP flags VCF[0] */
    vector_wipe(cf_ne);
    vector_wipe(cf_co);
    return;
}

INLINE static void clr_bi(pi16 VD, pi16 VS, pi16 VT)
{ /* clear CARRY and borrow in to accumulators */
    register int i;

    for (i = 0; i < N; i++)
        VACC_L[i] = VS[i] - VT[i] - cf_co[i];
    SIGNED_CLAMP_SUB(VD, VS, VT);

 /* CTC2    $0, $vco # zeroing RSP flags VCF[0] */
    vector_wipe(cf_ne);
    vector_wipe(cf_co);
    return;
}

/*
 * -1:  VT *= -1, because VS < 0 // VT ^= -2 if even, or ^= -1, += 1
 *  0:  VT *=  0, because VS = 0 // VT ^= VT
 * +1:  VT *= +1, because VS > 0 // VT ^=  0
 *      VT ^= -1, "negate" -32768 as ~+32767 (corner case hack for N64 SP)
 */
INLINE static void do_abs(pi16 VD, pi16 VS, pi16 VT)
{
    i16 neg[N], pos[N];
    i16 nez[N], cch[N]; /* corner case hack -- abs(-32768) == +32767 */
    ALIGNED i16 res[N];
    register int i;

    vector_copy(res, VT);
    for (i = 0; i < N; i++)
        cch[i]  = (res[i] == -32768);

    for (i = 0; i < N; i++)
        neg[i]  = (VS[i] <  0x0000);
    for (i = 0; i < N; i++)
        pos[i]  = (VS[i] >  0x0000);
    vector_wipe(nez);

    for (i = 0; i < N; i++)
        nez[i] -= neg[i];
    for (i = 0; i < N; i++)
        nez[i] += pos[i];

    for (i = 0; i < N; i++)
        res[i] *= nez[i];
    for (i = 0; i < N; i++)
        res[i] -= cch[i];
    vector_copy(VACC_L, res);
    vector_copy(VD, VACC_L);
    return;
}

INLINE static void set_co(pi16 VD, pi16 VS, pi16 VT)
{ /* set CARRY and carry out from sum */
    i32 sum[N];
    register int i;

    for (i = 0; i < N; i++)
        sum[i] = (u16)(VS[i]) + (u16)(VT[i]);
    for (i = 0; i < N; i++)
        VACC_L[i] = VS[i] + VT[i];
    vector_copy(VD, VACC_L);

    vector_wipe(cf_ne);
    for (i = 0; i < N; i++)
        cf_co[i] = sum[i] >> 16; /* native:  (sum[i] > +65535) */
    return;
}

INLINE static void set_bo(pi16 VD, pi16 VS, pi16 VT)
{ /* set CARRY and borrow out from difference */
    i32 dif[N];
    register int i;

    for (i = 0; i < N; i++)
        dif[i] = (u16)(VS[i]) - (u16)(VT[i]);
    for (i = 0; i < N; i++)
        VACC_L[i] = VS[i] - VT[i];
    for (i = 0; i < N; i++)
        cf_ne[i] = (VS[i] != VT[i]);
    for (i = 0; i < N; i++)
        cf_co[i] = (dif[i] < 0);
    vector_copy(VD, VACC_L);
    return;
}

VECTOR_OPERATION VADD(v16 vs, v16 vt)
{
    ALIGNED i16 VD[N];
#ifdef ARCH_MIN_SSE2
    ALIGNED i16 VS[N], VT[N];

    *(v16 *)VS = vs;
    *(v16 *)VT = vt;
#else
    v16 VS, VT;

    VS = vs;
    VT = vt;
#endif
    clr_ci(VD, VS, VT);
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VD;
    return (vs);
#else
    vector_copy(V_result, VD);
    return;
#endif
}

VECTOR_OPERATION VSUB(v16 vs, v16 vt)
{
    ALIGNED i16 VD[N];
#ifdef ARCH_MIN_SSE2
    ALIGNED i16 VS[N], VT[N];

    *(v16 *)VS = vs;
    *(v16 *)VT = vt;
#else
    v16 VS, VT;

    VS = vs;
    VT = vt;
#endif
    clr_bi(VD, VS, VT);
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VD;
    return (vs);
#else
    vector_copy(V_result, VD);
    return;
#endif
}

VECTOR_OPERATION VABS(v16 vs, v16 vt)
{
    ALIGNED i16 VD[N];
#ifdef ARCH_MIN_SSE2
    ALIGNED i16 VS[N], VT[N];

    *(v16 *)VS = vs;
    *(v16 *)VT = vt;
#else
    v16 VS, VT;

    VS = vs;
    VT = vt;
#endif
    do_abs(VD, VS, VT);
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VD;
    return (vs);
#else
    vector_copy(V_result, VD);
    return;
#endif
}

VECTOR_OPERATION VADDC(v16 vs, v16 vt)
{
    ALIGNED i16 VD[N];
#ifdef ARCH_MIN_SSE2
    ALIGNED i16 VS[N], VT[N];

    *(v16 *)VS = vs;
    *(v16 *)VT = vt;
#else
    v16 VS, VT;

    VS = vs;
    VT = vt;
#endif
    set_co(VD, VS, VT);
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VD;
    return (vs);
#else
    vector_copy(V_result, VD);
    return;
#endif
}

VECTOR_OPERATION VSUBC(v16 vs, v16 vt)
{
    ALIGNED i16 VD[N];
#ifdef ARCH_MIN_SSE2
    ALIGNED i16 VS[N], VT[N];

    *(v16 *)VS = vs;
    *(v16 *)VT = vt;
#else
    v16 VS, VT;

    VS = vs;
    VT = vt;
#endif
    set_bo(VD, VS, VT);
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VD;
    return (vs);
#else
    vector_copy(V_result, VD);
    return;
#endif
}

VECTOR_OPERATION VSAW(v16 vs, v16 vt)
{
    unsigned int element;

    element  = 0xF & (inst_word >> 21);
    element ^= 0x8; /* Convert scalar whole elements 8:F to 0:7. */

    if (element > 0x2) {
        message("VSAW\nIllegal mask.");
#ifdef ARCH_MIN_SSE2
        vector_wipe(vs);
#else
        vector_wipe(V_result);
#endif
    } else {
#ifdef ARCH_MIN_SSE2
        vs = *(v16 *)VACC[element];
#else
        vector_copy(V_result, VACC[element]);
#endif
    }
#ifdef ARCH_MIN_SSE2
    return (vt = vs);
#else
    if (vt == vs)
        return; /* -Wunused-but-set-parameter */
    return;
#endif
}
