/******************************************************************************\
* Project:  MSP Simulation Layer for Vector Unit Computational Multiplies      *
* Authors:  Iconoclast                                                         *
* Release:  2015.11.30                                                         *
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

#include "multiply.h"

#ifdef ARCH_MIN_SSE2
#define _mm_cmple_epu16(dst, src) \
    _mm_cmpeq_epi16(_mm_subs_epu16(dst, src), _mm_setzero_si128())
#define _mm_cmpgt_epu16(dst, src) \
    _mm_andnot_si128(_mm_cmpeq_epi16(dst, src), _mm_cmple_epu16(src, dst))
#define _mm_cmplt_epu16(dst, src) \
    _mm_cmpgt_epu16(src, dst)

#define _mm_mullo_epu16(dst, src) \
    _mm_mullo_epi16(dst, src)

static INLINE void SIGNED_CLAMP_AM(pi16 VD)
{ /* typical sign-clamp of accumulator-mid (bits 31:16) */
    v16 dst, src;
    v16 pvd, pvs;

    pvs = _mm_load_si128((v16 *)VACC_H);
    pvd = _mm_load_si128((v16 *)VACC_M);
    dst = _mm_unpacklo_epi16(pvd, pvs);
    src = _mm_unpackhi_epi16(pvd, pvs);

    dst = _mm_packs_epi32(dst, src);
    _mm_store_si128((v16 *)VD, dst);
    return;
}
#else
static INLINE void SIGNED_CLAMP_AM(pi16 VD)
{ /* typical sign-clamp of accumulator-mid (bits 31:16) */
    i16 hi[N], lo[N];
    register int i;

    for (i = 0; i < N; i++)
        lo[i]  = (VACC_H[i] < ~0);
    for (i = 0; i < N; i++)
        lo[i] |= (VACC_H[i] < 0) & !(VACC_M[i] < 0);
    for (i = 0; i < N; i++)
        hi[i]  = (VACC_H[i] >  0);
    for (i = 0; i < N; i++)
        hi[i] |= (VACC_H[i] == 0) & (VACC_M[i] < 0);
    vector_copy(VD, VACC_M);
    for (i = 0; i < N; i++)
        VD[i] &= -(lo[i] ^ 1);
    for (i = 0; i < N; i++)
        VD[i] |= -(hi[i] ^ 0);
    for (i = 0; i < N; i++)
        VD[i] ^= 0x8000 * (hi[i] | lo[i]);
    return;
}
#endif

static INLINE void UNSIGNED_CLAMP(pi16 VD)
{ /* sign-zero hybrid clamp of accumulator-mid (bits 31:16) */
    ALIGNED i16 temp[N];
    i16 cond[N];
    register int i;

    SIGNED_CLAMP_AM(temp); /* no direct map in SSE, but closely based on this */
    for (i = 0; i < N; i++)
        cond[i] = -(temp[i] >  VACC_M[i]); /* VD |= -(ACC47..16 > +32767) */
    for (i = 0; i < N; i++)
        VD[i] = temp[i] & ~(temp[i] >> 15); /* Only this clamp is unsigned. */
    for (i = 0; i < N; i++)
        VD[i] = VD[i] | cond[i];
    return;
}

static INLINE void SIGNED_CLAMP_AL(pi16 VD)
{ /* sign-clamp accumulator-low (bits 15:0) */
    ALIGNED i16 temp[N];
    i16 cond[N];
    register int i;

    SIGNED_CLAMP_AM(temp); /* no direct map in SSE, but closely based on this */
    for (i = 0; i < N; i++)
        cond[i] = (temp[i] != VACC_M[i]); /* result_clamped != result_raw ? */
    for (i = 0; i < N; i++)
        temp[i] ^= 0x8000; /* clamps 0x0000:0xFFFF instead of -0x8000:+0x7FFF */
    for (i = 0; i < N; i++)
        VD[i] = (cond[i] ? temp[i] : VACC_L[i]);
    return;
}

INLINE static void do_macf(pi16 VD, pi16 VS, pi16 VT)
{
    i32 product[N];
    u32 addend[N];
    register int i;

    for (i = 0; i < N; i++)
        product[i] = VS[i] * VT[i];
    for (i = 0; i < N; i++)
        addend[i] = (product[i] << 1) & 0x00000000FFFF;
    for (i = 0; i < N; i++)
        addend[i] = (u16)(VACC_L[i]) + addend[i];
    for (i = 0; i < N; i++)
        VACC_L[i] = (i16)(addend[i]);
    for (i = 0; i < N; i++)
        addend[i] = (addend[i] >> 16) + (u16)(product[i] >> 15);
    for (i = 0; i < N; i++)
        addend[i] = (u16)(VACC_M[i]) + addend[i];
    for (i = 0; i < N; i++)
        VACC_M[i] = (i16)(addend[i]);
    for (i = 0; i < N; i++)
        VACC_H[i] -= (product[i] < 0);
    for (i = 0; i < N; i++)
        VACC_H[i] += addend[i] >> 16;
    SIGNED_CLAMP_AM(VD);
    return;
}

INLINE static void do_macu(pi16 VD, pi16 VS, pi16 VT)
{
    i32 product[N];
    u32 addend[N];
    register int i;

    for (i = 0; i < N; i++)
        product[i] = VS[i] * VT[i];
    for (i = 0; i < N; i++)
        addend[i] = (product[i] << 1) & 0x00000000FFFF;
    for (i = 0; i < N; i++)
        addend[i] = (u16)(VACC_L[i]) + addend[i];
    for (i = 0; i < N; i++)
        VACC_L[i] = (i16)(addend[i]);
    for (i = 0; i < N; i++)
        addend[i] = (addend[i] >> 16) + (u16)(product[i] >> 15);
    for (i = 0; i < N; i++)
        addend[i] = (u16)(VACC_M[i]) + addend[i];
    for (i = 0; i < N; i++)
        VACC_M[i] = (i16)(addend[i]);
    for (i = 0; i < N; i++)
        VACC_H[i] -= (product[i] < 0);
    for (i = 0; i < N; i++)
        VACC_H[i] += addend[i] >> 16;
    UNSIGNED_CLAMP(VD);
    return;
}

VECTOR_OPERATION VMULF(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    v16 negative;
    v16 round;
    v16 prod_hi, prod_lo;

/*
 * We cannot save register allocations by doing xmm0 *= xmm1 or xmm1 *= xmm0
 * because we need to do future computations on the original source factors.
 */
    prod_lo = _mm_mullo_epi16(vs, vt);
    prod_hi = _mm_mulhi_epi16(vs, vt);

/*
 * The final product is really 2*s*t + 32768.  Fortunately for us, however,
 * no two 16-bit values can cause overflow when <<= 1 the HIGH word, anyway.
 */
    prod_hi = _mm_add_epi16(prod_hi, prod_hi); /* fast way of doing <<= 1 */
    negative = _mm_srli_epi16(prod_lo, 15); /* shifting LOW overflows ? 1 : 0 */
    prod_hi = _mm_add_epi16(prod_hi, negative); /* hi<<1 += MSB of lo */
    prod_lo = _mm_add_epi16(prod_lo, prod_lo); /* fast way of doing <<= 1 */
    negative = _mm_srli_epi16(prod_lo, 15); /* Adding 0x8000 sets MSB to 0? */

/*
 * special fractional round value:  (32-bit product) += 32768 (0x8000)
 * two's compliment computation:  (0xFFFF << 15) & 0xFFFF
 */
    round = _mm_cmpeq_epi16(vs, vs); /* PCMPEQW xmmA, xmmA # all 1's forced */
    round = _mm_slli_epi16(round, 15);

    prod_lo = _mm_xor_si128(prod_lo, round); /* Or += 32768 works also. */
    *(v16 *)VACC_L = prod_lo;
    prod_hi = _mm_add_epi16(prod_hi, negative);
    *(v16 *)VACC_M = prod_hi;

/*
 * VMULF does signed clamping.  However, in VMULF's case, the only possible
 * combination of inputs to even cause a 32-bit signed clamp to a saturated
 * 16-bit result is (-32768 * -32768), so, rather than fully emulating a
 * signed clamp with SSE, we do an accurate-enough hack for this corner case.
 */
    negative = _mm_srai_epi16(prod_hi, 15);
    vs = _mm_cmpeq_epi16(vs, round); /* vs == -32768 ? ~0 : 0 */
    vt = _mm_cmpeq_epi16(vt, round); /* vt == -32768 ? ~0 : 0 */
    vs = _mm_and_si128(vs, vt); /* vs == vt == -32768:  corner case confirmed */

    negative = _mm_xor_si128(negative, vs);
    *(v16 *)VACC_H = negative; /* 2*i16*i16 only fills L/M; VACC_H = 0 or ~0. */
    vs = _mm_add_epi16(vs, prod_hi); /* prod_hi must be -32768; + -1 = +32767 */
    return (vs);
#else
    word_64 product[N]; /* (-32768 * -32768)<<1 + 32768 confuses 32-bit type. */
    register unsigned int i;

    for (i = 0; i < N; i++)
        product[i].W = vs[i] * vt[i];
    for (i = 0; i < N; i++)
        product[i].W <<= 1; /* special fractional shift value */
    for (i = 0; i < N; i++)
        product[i].W += 32768; /* special fractional round value */
    for (i = 0; i < N; i++)
        VACC_L[i] = (product[i].UW & 0x00000000FFFF) >>  0;
    for (i = 0; i < N; i++)
        VACC_M[i] = (product[i].UW & 0x0000FFFF0000) >> 16;
    for (i = 0; i < N; i++)
        VACC_H[i] = -(product[i].SW < 0); /* product>>32 & 0xFFFF */
    SIGNED_CLAMP_AM(V_result);
    return;
#endif
}

VECTOR_OPERATION VMULU(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    v16 negative;
    v16 round;
    v16 prod_hi, prod_lo;

/*
 * Besides the unsigned clamping method (as opposed to VMULF's signed clamp),
 * this operation's multiplication matches VMULF.  See VMULF for annotations.
 */
    prod_lo = _mm_mullo_epi16(vs, vt);
    prod_hi = _mm_mulhi_epi16(vs, vt);

    prod_hi = _mm_add_epi16(prod_hi, prod_hi);
    negative = _mm_srli_epi16(prod_lo, 15);
    prod_hi = _mm_add_epi16(prod_hi, negative);
    prod_lo = _mm_add_epi16(prod_lo, prod_lo);
    negative = _mm_srli_epi16(prod_lo, 15);

    round = _mm_cmpeq_epi16(vs, vs);
    round = _mm_slli_epi16(round, 15);

    prod_lo = _mm_xor_si128(prod_lo, round);
    *(v16 *)VACC_L = prod_lo;
    prod_hi = _mm_add_epi16(prod_hi, negative);
    *(v16 *)VACC_M = prod_hi;

/*
 * VMULU does unsigned clamping.  However, in VMULU's case, the only possible
 * combinations that overflow, are either negative values or -32768 * -32768.
 */
    negative = _mm_srai_epi16(prod_hi, 15);
    vs = _mm_cmpeq_epi16(vs, round); /* vs == -32768 ? ~0 : 0 */
    vt = _mm_cmpeq_epi16(vt, round); /* vt == -32768 ? ~0 : 0 */
    vs = _mm_and_si128(vs, vt); /* vs == vt == -32768:  corner case confirmed */
    negative = _mm_xor_si128(negative, vs);
    *(v16 *)VACC_H = negative; /* 2*i16*i16 only fills L/M; VACC_H = 0 or ~0. */

    prod_lo = _mm_srai_epi16(prod_hi, 15); /* unsigned overflow mask */
    vs = _mm_or_si128(prod_hi, prod_lo);
    vs = _mm_andnot_si128(negative, vs); /* unsigned underflow mask */
    return (vs);
#else
    word_64 product[N]; /* (-32768 * -32768)<<1 + 32768 confuses 32-bit type. */
    register unsigned int i;

    for (i = 0; i < N; i++)
        product[i].W = vs[i] * vt[i];
    for (i = 0; i < N; i++)
        product[i].W <<= 1; /* special fractional shift value */
    for (i = 0; i < N; i++)
        product[i].W += 32768; /* special fractional round value */
    for (i = 0; i < N; i++)
        VACC_L[i] = (product[i].UW & 0x00000000FFFF) >>  0;
    for (i = 0; i < N; i++)
        VACC_M[i] = (product[i].UW & 0x0000FFFF0000) >> 16;
    for (i = 0; i < N; i++)
        VACC_H[i] = -(product[i].SW < 0); /* product>>32 & 0xFFFF */
    UNSIGNED_CLAMP(V_result);
    return;
#endif
}

VECTOR_OPERATION VMUDL(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    vs = _mm_mulhi_epu16(vs, vt);
    vector_wipe(vt); /* (UINT16_MAX * UINT16_MAX) >> 16 too small for MD/HI */
    *(v16 *)VACC_L = vs;
    *(v16 *)VACC_M = vt;
    *(v16 *)VACC_H = vt;
    return (vs); /* no possibilities to clamp */
#else
    word_32 product[N];
    register unsigned int i;

    for (i = 0; i < N; i++)
        product[i].UW = (u16)vs[i] * (u16)vt[i];
    for (i = 0; i < N; i++)
        VACC_L[i] = product[i].UW >> 16; /* product[i].H[HES(0) >> 1] */
    vector_copy(V_result, VACC_L);
    vector_wipe(VACC_M);
    vector_wipe(VACC_H);
    return;
#endif
}

VECTOR_OPERATION VMUDM(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    v16 prod_hi, prod_lo;

    prod_lo = _mm_mullo_epi16(vs, vt);
    prod_hi = _mm_mulhi_epu16(vs, vt);

/*
 * Based on a little pattern found by MarathonMan...
 * If (vs < 0), then high 16 bits of (u16)vs * (u16)vt += ~(vt) + 1, or -vt.
 */
    vs = _mm_srai_epi16(vs, 15);
    vt = _mm_and_si128(vt, vs);
    prod_hi = _mm_sub_epi16(prod_hi, vt);

    *(v16 *)VACC_L = prod_lo;
    *(v16 *)VACC_M = prod_hi;
    vs = prod_hi;
    prod_hi = _mm_srai_epi16(prod_hi, 15);
    *(v16 *)VACC_H = prod_hi;
    return (vs);
#else
    word_32 product[N];
    register unsigned int i;

    for (i = 0; i < N; i++)
        product[i].SW = (s16)vs[i] * (u16)vt[i];
    for (i = 0; i < N; i++)
        VACC_L[i] = (product[i].W & 0x00000000FFFF) >>  0;
    for (i = 0; i < N; i++)
        VACC_M[i] = (product[i].W & 0x0000FFFF0000) >> 16;
    for (i = 0; i < N; i++)
        VACC_H[i] = -(VACC_M[i] < 0);
    vector_copy(V_result, VACC_M);
    return;
#endif
}

VECTOR_OPERATION VMUDN(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    v16 prod_hi, prod_lo;

    prod_lo = _mm_mullo_epi16(vs, vt);
    prod_hi = _mm_mulhi_epu16(vs, vt);

/*
 * Based on the pattern discovered for the similar VMUDM operation.
 * If (vt < 0), then high 16 bits of (u16)vs * (u16)vt += ~(vs) + 1, or -vs.
 */
    vt = _mm_srai_epi16(vt, 15);
    vs = _mm_and_si128(vs, vt);
    prod_hi = _mm_sub_epi16(prod_hi, vs);

    *(v16 *)VACC_L = prod_lo;
    *(v16 *)VACC_M = prod_hi;
    prod_hi = _mm_srai_epi16(prod_hi, 15);
    *(v16 *)VACC_H = prod_hi;
    return (vs = prod_lo);
#else
    word_32 product[N];
    register unsigned int i;

    for (i = 0; i < N; i++)
        product[i].SW = (u16)vs[i] * (s16)vt[i];
    for (i = 0; i < N; i++)
        VACC_L[i] = (product[i].W & 0x00000000FFFF) >>  0;
    for (i = 0; i < N; i++)
        VACC_M[i] = (product[i].W & 0x0000FFFF0000) >> 16;
    for (i = 0; i < N; i++)
        VACC_H[i] = -(VACC_M[i] < 0);
    vector_copy(V_result, VACC_L);
    return;
#endif
}

VECTOR_OPERATION VMUDH(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    v16 prod_high;

    prod_high = _mm_mulhi_epi16(vs, vt);
    vs        = _mm_mullo_epi16(vs, vt);

    *(v16 *)VACC_L = _mm_setzero_si128();
    *(v16 *)VACC_M = vs; /* acc 31..16 storing (VS*VT)15..0 */
    *(v16 *)VACC_H = prod_high; /* acc 47..32 storing (VS*VT)31..16 */

/*
 * "Unpack" the low 16 bits and the high 16 bits of each 32-bit product to a
 * couple xmm registers, re-storing them as 2 32-bit products each.
 */
    vt = _mm_unpackhi_epi16(vs, prod_high);
    vs = _mm_unpacklo_epi16(vs, prod_high);

/*
 * Re-interleave or pack both 32-bit products in both xmm registers with
 * signed saturation:  prod < -32768 to -32768 and prod > +32767 to +32767.
 */
    vs = _mm_packs_epi32(vs, vt);
    return (vs);
#else
    word_32 product[N];
    register unsigned int i;

    for (i = 0; i < N; i++)
        product[i].SW = (s16)vs[i] * (s16)vt[i];
    vector_wipe(VACC_L);
    for (i = 0; i < N; i++)
        VACC_M[i] = (s16)(product[i].W >>  0); /* product[i].HW[HES(0) >> 1] */
    for (i = 0; i < N; i++)
        VACC_H[i] = (s16)(product[i].W >> 16); /* product[i].HW[HES(2) >> 1] */
    SIGNED_CLAMP_AM(V_result);
    return;
#endif
}

VECTOR_OPERATION VMACF(v16 vs, v16 vt)
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
    do_macf(VD, VS, VT);
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VD;
    return (vs);
#else
    vector_copy(V_result, VD);
    return;
#endif
}

VECTOR_OPERATION VMACU(v16 vs, v16 vt)
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
    do_macu(VD, VS, VT);
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VD;
    return (vs);
#else
    vector_copy(V_result, VD);
    return;
#endif
}

VECTOR_OPERATION VMADL(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    v16 acc_hi, acc_md, acc_lo;
    v16 prod_hi;
    v16 overflow, overflow_new;

 /* prod_lo = _mm_mullo_epu16(vs, vt); */
    prod_hi = _mm_mulhi_epu16(vs, vt);

    acc_lo = *(v16 *)VACC_L;
    acc_md = *(v16 *)VACC_M;
    acc_hi = *(v16 *)VACC_H;

    acc_lo = _mm_add_epi16(acc_lo, prod_hi);
    *(v16 *)VACC_L = acc_lo;

    overflow = _mm_cmplt_epu16(acc_lo, prod_hi); /* overflow:  (x + y < y) */
    acc_md = _mm_sub_epi16(acc_md, overflow);
    *(v16 *)VACC_M = acc_md;

/*
 * Luckily for us, taking unsigned * unsigned always evaluates to something
 * nonnegative, so we only have to worry about overflow from accumulating.
 */
    overflow_new = _mm_cmpeq_epi16(acc_md, _mm_setzero_si128());
    overflow = _mm_and_si128(overflow, overflow_new);
    acc_hi = _mm_sub_epi16(acc_hi, overflow);
    *(v16 *)VACC_H = acc_hi;

/*
 * Do a signed clamp...sort of (VM?DM, VM?DH:  middle; VM?DL, VM?DN:  low).
 *     if (acc_47..16 < -32768) result = -32768 ^ 0x8000;      # 0000
 *     else if (acc_47..16 > +32767) result = +32767 ^ 0x8000; # FFFF
 *     else { result = acc_15..0 & 0xFFFF; }
 * So it is based on the standard signed clamping logic for VM?DM, VM?DH,
 * except that extra steps must be concatenated to that definition.
 */
    vt = _mm_unpackhi_epi16(acc_md, acc_hi);
    vs = _mm_unpacklo_epi16(acc_md, acc_hi);
    vs = _mm_packs_epi32(vs, vt);

    acc_md = _mm_cmpeq_epi16(acc_md, vs); /* (unclamped == clamped) ... */
    acc_lo = _mm_and_si128(acc_lo, acc_md); /* ... ? low : mid */
    vt = _mm_cmpeq_epi16(vt, vt);
    acc_md = _mm_xor_si128(acc_md, vt); /* (unclamped != clamped) ... */

    vs = _mm_and_si128(vs, acc_md); /* ... ? VS_clamped : 0x0000 */
    vs = _mm_or_si128(vs, acc_lo); /*                   : acc_lo */
    acc_md = _mm_slli_epi16(acc_md, 15); /* ... ? ^ 0x8000 : ^ 0x0000 */
    vs = _mm_xor_si128(vs, acc_md); /* Stupid unsigned-clamp-ish adjustment. */
    return (vs);
#else
    word_32 product[N], addend[N];
    register unsigned int i;

    for (i = 0; i < N; i++)
        product[i].UW = (u16)vs[i] * (u16)vt[i];
    for (i = 0; i < N; i++)
        addend[i].UW = (u16)(product[i].UW >> 16) + (u16)VACC_L[i];
    for (i = 0; i < N; i++)
        VACC_L[i] = addend[i].UW & 0x0000FFFF;
    for (i = 0; i < N; i++)
        addend[i].UW = (addend[i].UW >> 16) + (0x000000000000 >> 16);
    for (i = 0; i < N; i++)
        addend[i].UW += (u16)VACC_M[i];
    for (i = 0; i < N; i++)
        VACC_M[i] = addend[i].UW & 0x0000FFFF;
    for (i = 0; i < N; i++)
        VACC_H[i] += addend[i].UW >> 16;
    SIGNED_CLAMP_AL(V_result);
    return;
#endif
}

VECTOR_OPERATION VMADM(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    v16 acc_hi, acc_md, acc_lo;
    v16 prod_hi, prod_lo;
    v16 overflow;

    prod_lo = _mm_mullo_epi16(vs, vt);
    prod_hi = _mm_mulhi_epu16(vs, vt);

    vs = _mm_srai_epi16(vs, 15);
    vt = _mm_and_si128(vt, vs);
    prod_hi = _mm_sub_epi16(prod_hi, vt);

/*
 * Writeback phase to the accumulator.
 * VMADM stores accumulator += the product achieved by VMUDM.
 */
    acc_lo = *(v16 *)VACC_L;
    acc_md = *(v16 *)VACC_M;
    acc_hi = *(v16 *)VACC_H;

    acc_lo = _mm_add_epi16(acc_lo, prod_lo);
    *(v16 *)VACC_L = acc_lo;

    overflow = _mm_cmplt_epu16(acc_lo, prod_lo); /* overflow:  (x + y < y) */
    prod_hi = _mm_sub_epi16(prod_hi, overflow);
    acc_md = _mm_add_epi16(acc_md, prod_hi);
    *(v16 *)VACC_M = acc_md;

    overflow = _mm_cmplt_epu16(acc_md, prod_hi);
    prod_hi = _mm_srai_epi16(prod_hi, 15);
    acc_hi = _mm_add_epi16(acc_hi, prod_hi);
    acc_hi = _mm_sub_epi16(acc_hi, overflow);
    *(v16 *)VACC_H = acc_hi;

    vt = _mm_unpackhi_epi16(acc_md, acc_hi);
    vs = _mm_unpacklo_epi16(acc_md, acc_hi);
    vs = _mm_packs_epi32(vs, vt);
    return (vs);
#else
    word_32 product[N], addend[N];
    register unsigned int i;

    for (i = 0; i < N; i++)
        product[i].SW = (s16)vs[i] * (u16)vt[i];
    for (i = 0; i < N; i++)
        addend[i].UW = (product[i].W & 0x0000FFFF) + (u16)VACC_L[i];
    for (i = 0; i < N; i++)
        VACC_L[i] = addend[i].UW & 0x0000FFFF;
    for (i = 0; i < N; i++)
        addend[i].UW = (addend[i].UW >> 16) + (product[i].SW >> 16);
    for (i = 0; i < N; i++)
        addend[i].UW += (u16)VACC_M[i];
    for (i = 0; i < N; i++)
        VACC_M[i] = addend[i].UW & 0x0000FFFF;
    for (i = 0; i < N; i++)
        VACC_H[i] += addend[i].UW >> 16;
    SIGNED_CLAMP_AM(V_result);
    return;
#endif
}

VECTOR_OPERATION VMADN(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    v16 acc_hi, acc_md, acc_lo;
    v16 prod_hi, prod_lo;
    v16 overflow;

    prod_lo = _mm_mullo_epi16(vs, vt);
    prod_hi = _mm_mulhi_epu16(vs, vt);

    vt = _mm_srai_epi16(vt, 15);
    vs = _mm_and_si128(vs, vt);
    prod_hi = _mm_sub_epi16(prod_hi, vs);

/*
 * Writeback phase to the accumulator.
 * VMADN stores accumulator += the product achieved by VMUDN.
 */
    acc_lo = *(v16 *)VACC_L;
    acc_md = *(v16 *)VACC_M;
    acc_hi = *(v16 *)VACC_H;

    acc_lo = _mm_add_epi16(acc_lo, prod_lo);
    *(v16 *)VACC_L = acc_lo;

    overflow = _mm_cmplt_epu16(acc_lo, prod_lo); /* overflow:  (x + y < y) */
    prod_hi = _mm_sub_epi16(prod_hi, overflow);
    acc_md = _mm_add_epi16(acc_md, prod_hi);
    *(v16 *)VACC_M = acc_md;

    overflow = _mm_cmplt_epu16(acc_md, prod_hi);
    prod_hi = _mm_srai_epi16(prod_hi, 15);
    acc_hi = _mm_add_epi16(acc_hi, prod_hi);
    acc_hi = _mm_sub_epi16(acc_hi, overflow);
    *(v16 *)VACC_H = acc_hi;

/*
 * Do a signed clamp...sort of (VM?DM, VM?DH:  middle; VM?DL, VM?DN:  low).
 *     if (acc_47..16 < -32768) result = -32768 ^ 0x8000;      # 0000
 *     else if (acc_47..16 > +32767) result = +32767 ^ 0x8000; # FFFF
 *     else { result = acc_15..0 & 0xFFFF; }
 * So it is based on the standard signed clamping logic for VM?DM, VM?DH,
 * except that extra steps must be concatenated to that definition.
 */
    vt = _mm_unpackhi_epi16(acc_md, acc_hi);
    vs = _mm_unpacklo_epi16(acc_md, acc_hi);
    vs = _mm_packs_epi32(vs, vt);

    acc_md = _mm_cmpeq_epi16(acc_md, vs); /* (unclamped == clamped) ... */
    acc_lo = _mm_and_si128(acc_lo, acc_md); /* ... ? low : mid */
    vt = _mm_cmpeq_epi16(vt, vt);
    acc_md = _mm_xor_si128(acc_md, vt); /* (unclamped != clamped) ... */

    vs = _mm_and_si128(vs, acc_md); /* ... ? VS_clamped : 0x0000 */
    vs = _mm_or_si128(vs, acc_lo); /*                   : acc_lo */
    acc_md = _mm_slli_epi16(acc_md, 15); /* ... ? ^ 0x8000 : ^ 0x0000 */
    vs = _mm_xor_si128(vs, acc_md); /* Stupid unsigned-clamp-ish adjustment. */
    return (vs);
#else
    word_32 product[N], addend[N];
    register unsigned int i;

    for (i = 0; i < N; i++)
        product[i].SW = (u16)vs[i] * (s16)vt[i];
    for (i = 0; i < N; i++)
        addend[i].UW = (product[i].W & 0x0000FFFF) + (u16)VACC_L[i];
    for (i = 0; i < N; i++)
        VACC_L[i] = addend[i].UW & 0x0000FFFF;
    for (i = 0; i < N; i++)
        addend[i].UW = (addend[i].UW >> 16) + (product[i].SW >> 16);
    for (i = 0; i < N; i++)
        addend[i].UW += (u16)VACC_M[i];
    for (i = 0; i < N; i++)
        VACC_M[i] = addend[i].UW & 0x0000FFFF;
    for (i = 0; i < N; i++)
        VACC_H[i] += addend[i].UW >> 16;
    SIGNED_CLAMP_AL(V_result);
    return;
#endif
}

VECTOR_OPERATION VMADH(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    v16 acc_mid;
    v16 prod_high;

    prod_high = _mm_mulhi_epi16(vs, vt);
    vs        = _mm_mullo_epi16(vs, vt);

/*
 * We're required to load the source product from the accumulator to add to.
 * While we're at it, conveniently sneak in a acc[31..16] += (vs*vt)[15..0].
 */
    acc_mid = *(v16 *)VACC_M;
    vs = _mm_add_epi16(vs, acc_mid);
    *(v16 *)VACC_M = vs;
    vt = *(v16 *)VACC_H;

/*
 * While accumulating base_lo + product_lo is easy, getting the correct data
 * for base_hi + product_hi is tricky and needs unsigned overflow detection.
 *
 * The one-liner solution to detecting unsigned overflow (thus adding a carry
 * value of 1 to the higher word) is _mm_cmplt_epu16, but none of the Intel
 * MMX-based instruction sets define unsigned comparison ops FOR us, so...
 */
    vt = _mm_add_epi16(vt, prod_high);
    vs = _mm_cmplt_epu16(vs, acc_mid); /* acc.mid + prod.low < acc.mid */
    vt = _mm_sub_epi16(vt, vs); /* += 1 if overflow, by doing -= ~0 */
    *(v16 *)VACC_H = vt;

    vs = *(v16 *)VACC_M;
    prod_high = _mm_unpackhi_epi16(vs, vt);
    vs        = _mm_unpacklo_epi16(vs, vt);
    vs = _mm_packs_epi32(vs, prod_high);
    return (vs);
#else
    word_32 product[N], addend[N];
    register unsigned int i;

    for (i = 0; i < N; i++)
        product[i].SW = (s16)vs[i] * (s16)vt[i];
    for (i = 0; i < N; i++)
        addend[i].UW = (u16)VACC_M[i] + (u16)(product[i].W);
    for (i = 0; i < N; i++)
        VACC_M[i] += (i16)product[i].SW;
    for (i = 0; i < N; i++)
        VACC_H[i] += (addend[i].UW >> 16) + (product[i].SW >> 16);
    SIGNED_CLAMP_AM(V_result);
    return;
#endif
}
