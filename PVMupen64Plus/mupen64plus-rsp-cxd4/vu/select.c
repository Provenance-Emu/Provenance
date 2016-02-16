/******************************************************************************\
* Project:  MSP Simulation Layer for Vector Unit Computational Test Selects    *
* Authors:  Iconoclast                                                         *
* Release:  2015.01.30                                                         *
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

#include "select.h"

/*
 * vector select merge (`VMRG`) formula
 *
 * This is really just a vectorizer for ternary conditional storage.
 * I've named it so because it directly maps to the VMRG op-code.
 * -- example --
 * for (i = 0; i < N; i++)
 *     if (c_pass)
 *         dest = element_a;
 *     else
 *         dest = element_b;
 */
static void merge(pi16 VD, pi16 cmp, pi16 pass, pi16 fail)
{
    register int i;
#if (0 != 0)
/* Do not use this version yet, as it still does not vectorize to SSE2. */
    for (i = 0; i < N; i++)
        VD[i] = (cmp[i] != 0) ? pass[i] : fail[i];
#else
    i16 diff[N];

    for (i = 0; i < N; i++)
        diff[i] = pass[i] - fail[i];
    for (i = 0; i < N; i++)
        VD[i] = fail[i] + cmp[i]*diff[i]; /* actually `(cmp[i] != 0)*diff[i]` */
#endif
    return;
}

INLINE static void do_lt(pi16 VD, pi16 VS, pi16 VT)
{
    i16 cn[N];
    i16 eq[N];
    register int i;

    for (i = 0; i < N; i++)
        eq[i] = (VS[i] == VT[i]);
    for (i = 0; i < N; i++)
        cn[i] = cf_ne[i] & cf_co[i];
    for (i = 0; i < N; i++)
        eq[i] = eq[i] & cn[i];
    for (i = 0; i < N; i++)
        cf_comp[i] = (VS[i] < VT[i]); /* less than */
    for (i = 0; i < N; i++)
        cf_comp[i] = cf_comp[i] | eq[i]; /* ... or equal (uncommonly) */

    merge(VACC_L, cf_comp, VS, VT);
    vector_copy(VD, VACC_L);

 /* CTC2    $0, $vco # zeroing RSP flags VCF[0] */
    vector_wipe(cf_ne);
    vector_wipe(cf_co);

    vector_wipe(cf_clip);
    return;
}

INLINE static void do_eq(pi16 VD, pi16 VS, pi16 VT)
{
    register int i;

    for (i = 0; i < N; i++)
        cf_comp[i] = (VS[i] == VT[i]);
    for (i = 0; i < N; i++)
        cf_comp[i] = cf_comp[i] & (cf_ne[i] ^ 1);
#if (0)
    merge(VACC_L, cf_comp, VS, VT); /* correct but redundant */
#else
    vector_copy(VACC_L, VT);
#endif
    vector_copy(VD, VACC_L);

 /* CTC2    $0, $vco # zeroing RSP flags VCF[0] */
    vector_wipe(cf_ne);
    vector_wipe(cf_co);

    vector_wipe(cf_clip);
    return;
}

INLINE static void do_ne(pi16 VD, pi16 VS, pi16 VT)
{
    register int i;

    for (i = 0; i < N; i++)
        cf_comp[i] = (VS[i] != VT[i]);
    for (i = 0; i < N; i++)
        cf_comp[i] = cf_comp[i] | cf_ne[i];
#if (0)
    merge(VACC_L, cf_comp, VS, VT); /* correct but redundant */
#else
    vector_copy(VACC_L, VS);
#endif
    vector_copy(VD, VACC_L);

 /* CTC2    $0, $vco # zeroing RSP flags VCF[0] */
    vector_wipe(cf_ne);
    vector_wipe(cf_co);

    vector_wipe(cf_clip);
    return;
}

INLINE static void do_ge(pi16 VD, pi16 VS, pi16 VT)
{
    i16 ce[N];
    i16 eq[N];
    register int i;

    for (i = 0; i < N; i++)
        eq[i] = (VS[i] == VT[i]);
    for (i = 0; i < N; i++)
        ce[i] = (cf_ne[i] & cf_co[i]) ^ 1;
    for (i = 0; i < N; i++)
        eq[i] = eq[i] & ce[i];
    for (i = 0; i < N; i++)
        cf_comp[i] = (VS[i] > VT[i]); /* greater than */
    for (i = 0; i < N; i++)
        cf_comp[i] = cf_comp[i] | eq[i]; /* ... or equal (commonly) */

    merge(VACC_L, cf_comp, VS, VT);
    vector_copy(VD, VACC_L);

 /* CTC2    $0, $vco # zeroing RSP flags VCF[0] */
    vector_wipe(cf_ne);
    vector_wipe(cf_co);

    vector_wipe(cf_clip);
    return;
}

INLINE static void do_cl(pi16 VD, pi16 VS, pi16 VT)
{
    ALIGNED u16 VB[N], VC[N];
    ALIGNED i16 eq[N], ge[N], le[N];
    ALIGNED i16 gen[N], len[N], lz[N], uz[N], sn[N];
    i16 diff[N];
    i16 cmp[N];
    register int i;

    vector_copy((pi16)VB, VS);
    vector_copy((pi16)VC, VT);

/*
    for (i = 0; i < N; i++)
        ge[i] = cf_clip[i];
    for (i = 0; i < N; i++)
        le[i] = cf_comp[i];
*/
    for (i = 0; i < N; i++)
        eq[i] = cf_ne[i] ^ 1;
    vector_copy(sn, cf_co);

/*
 * Now that we have extracted all the flags, we will essentially be masking
 * them back in where they came from redundantly, unless the corresponding
 * NOTEQUAL bit from VCO upper was not set....
 */
    for (i = 0; i < N; i++)
        VC[i] = VC[i] ^ -sn[i];
    for (i = 0; i < N; i++)
        VC[i] = VC[i] + sn[i]; /* conditional negation, if sn */
    for (i = 0; i < N; i++)
        diff[i] = VB[i] - VC[i];
    for (i = 0; i < N; i++)
        uz[i] = (VB[i] + (u16)VT[i] - 65536) >> 31;
    for (i = 0; i < N; i++)
        lz[i] = (diff[i] == 0x0000);
    for (i = 0; i < N; i++)
        gen[i] = lz[i] | uz[i];
    for (i = 0; i < N; i++)
        len[i] = lz[i] & uz[i];
    for (i = 0; i < N; i++)
        gen[i] = gen[i] & cf_vce[i];
    for (i = 0; i < N; i++)
        len[i] = len[i] & (cf_vce[i] ^ 1);
    for (i = 0; i < N; i++)
        len[i] = len[i] | gen[i];
    for (i = 0; i < N; i++)
        gen[i] = (VB[i] >= VC[i]);

    for (i = 0; i < N; i++)
        cmp[i] = eq[i] & sn[i];
    merge(le, cmp, len, cf_comp);

    for (i = 0; i < N; i++)
        cmp[i] = eq[i] & (sn[i] ^ 1);
    merge(ge, cmp, gen, cf_clip);

    merge(cmp, sn, le, ge);
    merge(VACC_L, cmp, (pi16)VC, VS);
    vector_copy(VD, VACC_L);

 /* CTC2    $0, $vco # zeroing RSP flags VCF[0] */
    vector_wipe(cf_ne);
    vector_wipe(cf_co);

    vector_copy(cf_clip, ge);
    vector_copy(cf_comp, le);

 /* CTC2    $0, $vce # zeroing RSP flags VCF[2] */
    vector_wipe(cf_vce);
    return;
}

INLINE static void do_ch(pi16 VD, pi16 VS, pi16 VT)
{
    ALIGNED i16 VC[N];
    ALIGNED i16 eq[N], ge[N], le[N];
    ALIGNED i16 sn[N];
#ifndef _DEBUG
    i16 diff[N];
#endif
    i16 cch[N]; /* corner case hack:  -(-32768) with undefined sign */
    register int i;

    for (i = 0; i < N; i++)
        cch[i] = (VT[i] == -32768) ? ~0 : 0; /* -(-32768) might not be >= 0. */
    vector_copy(VC, VT);
    for (i = 0; i < N; i++)
        sn[i] = VS[i] ^ VT[i];
    for (i = 0; i < N; i++)
        sn[i] = (sn[i] < 0) ? ~0 :  0; /* signed SRA (sn), 15 */
    for (i = 0; i < N; i++)
        VC[i] ^= sn[i]; /* if (sn == ~0) {VT = ~VT;} else {VT =  VT;} */
    for (i = 0; i < N; i++)
        cf_vce[i]  = (VS[i] == VC[i]); /* 2's complement:  VC = -VT - 1 = ~VT */
    for (i = 0; i < N; i++)
        cf_vce[i] &= sn[i];
    for (i = 0; i < N; i++)
        VC[i] -= sn[i] & cch[i]; /* converts ~(VT) into -(VT) if (sign) */
    for (i = 0; i < N; i++)
        eq[i]  = (VS[i] == VC[i]) & ~cch[i]; /* (VS == +32768) is never true. */
    for (i = 0; i < N; i++)
        eq[i] |= cf_vce[i];

#ifdef _DEBUG
    for (i = 0; i < N; i++)
        le[i] = sn[i] ? (VS[i] <= VC[i]) : (VC[i] < 0);
    for (i = 0; i < N; i++)
        ge[i] = sn[i] ? (VC[i] > 0x0000) : (VS[i] >= VC[i]);
#elif (0)
    for (i = 0; i < N; i++)
        le[i] = sn[i] ? (VT[i] <= -VS[i]) : (VT[i] <= ~0x0000);
    for (i = 0; i < N; i++)
        ge[i] = sn[i] ? (~0x0000 >= VT[i]) : (VS[i] >= VT[i]);
#else
    for (i = 0; i < N; i++)
        diff[i] = sn[i] | VS[i];
    for (i = 0; i < N; i++)
        ge[i] = (diff[i] >= VT[i]);

    for (i = 0; i < N; i++)
        sn[i] = (u16)(sn[i]) >> 15; /* ~0 to 1, 0 to 0 */

    for (i = 0; i < N; i++)
        diff[i] = VC[i] - VS[i];
    for (i = 0; i < N; i++)
        diff[i] = (diff[i] >= 0);
    for (i = 0; i < N; i++)
        le[i] = (VT[i] < 0);
    merge(le, sn, diff, le);
#endif

    merge(cf_comp, sn, le, ge);
    merge(VACC_L, cf_comp, VC, VS);
    vector_copy(VD, VACC_L);

    vector_copy(cf_clip, ge);
    vector_copy(cf_comp, le);
    for (i = 0; i < N; i++)
        cf_ne[i] = eq[i] ^ 1;
    vector_copy(cf_co, sn);
    return;
}

INLINE static void do_cr(pi16 VD, pi16 VS, pi16 VT)
{
    ALIGNED i16 ge[N], le[N], sn[N];
    ALIGNED i16 VC[N];
    i16 cmp[N];
    register int i;

    vector_copy(VC, VT);
    for (i = 0; i < N; i++)
        sn[i] = VS[i] ^ VT[i];
    for (i = 0; i < N; i++)
        sn[i] = (sn[i] < 0) ? ~0 : 0;
#ifdef _DEBUG
    for (i = 0; i < N; i++)
        le[i] = sn[i] ? (VT[i] <= ~VS[i]) : (VT[i] <= ~0x0000);
    for (i = 0; i < N; i++)
        ge[i] = sn[i] ? (~0x0000 >= VT[i]) : (VS[i] >= VT[i]);
#else
    for (i = 0; i < N; i++)
        cmp[i] = ~(VS[i] & sn[i]);
    for (i = 0; i < N; i++)
        le[i] = (VT[i] <= cmp[i]);
    for (i = 0; i < N; i++)
        cmp[i] =  (VS[i] | sn[i]);
    for (i = 0; i < N; i++)
        ge[i] = (cmp[i] >= VT[i]);
#endif
    for (i = 0; i < N; i++)
        VC[i] ^= sn[i]; /* if (sn == ~0) {VT = ~VT;} else {VT =  VT;} */
    merge(cmp, sn, le, ge);
    merge(VACC_L, cmp, VC, VS);
    vector_copy(VD, VACC_L);

 /* CTC2    $0, $vco # zeroing RSP flags VCF[0] */
    vector_wipe(cf_ne);
    vector_wipe(cf_co);

    vector_copy(cf_clip, ge);
    vector_copy(cf_comp, le);

 /* CTC2    $0, $vce # zeroing RSP flags VCF[2] */
    vector_wipe(cf_vce);
    return;
}

INLINE static void do_mrg(pi16 VD, pi16 VS, pi16 VT)
{
    merge(VACC_L, cf_comp, VS, VT);
    vector_copy(VD, VACC_L);
    return;
}

VECTOR_OPERATION VLT(v16 vs, v16 vt)
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
    do_lt(VD, VS, VT);
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VD;
    return (vs);
#else
    vector_copy(V_result, VD);
    return;
#endif
}

VECTOR_OPERATION VEQ(v16 vs, v16 vt)
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
    do_eq(VD, VS, VT);
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VD;
    return (vs);
#else
    vector_copy(V_result, VD);
    return;
#endif
}

VECTOR_OPERATION VNE(v16 vs, v16 vt)
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
    do_ne(VD, VS, VT);
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VD;
    return (vs);
#else
    vector_copy(V_result, VD);
    return;
#endif
}

VECTOR_OPERATION VGE(v16 vs, v16 vt)
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
    do_ge(VD, VS, VT);
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VD;
    return (vs);
#else
    vector_copy(V_result, VD);
    return;
#endif
}

VECTOR_OPERATION VCL(v16 vs, v16 vt)
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
    do_cl(VD, VS, VT);
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VD;
    return (vs);
#else
    vector_copy(V_result, VD);
    return;
#endif
}

VECTOR_OPERATION VCH(v16 vs, v16 vt)
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
    do_ch(VD, VS, VT);
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VD;
    return (vs);
#else
    vector_copy(V_result, VD);
    return;
#endif
}

VECTOR_OPERATION VCR(v16 vs, v16 vt)
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
    do_cr(VD, VS, VT);
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VD;
    return (vs);
#else
    vector_copy(V_result, VD);
    return;
#endif
}

VECTOR_OPERATION VMRG(v16 vs, v16 vt)
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
    do_mrg(VD, VS, VT);
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VD;
    return (vs);
#else
    vector_copy(V_result, VD);
    return;
#endif
}
