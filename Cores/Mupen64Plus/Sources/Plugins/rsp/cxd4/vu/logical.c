/******************************************************************************\
* Project:  MSP Simulation Layer for Vector Unit Computational Bit-Wise Logic  *
* Authors:  Iconoclast                                                         *
* Release:  2014.10.15                                                         *
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

#include "logical.h"

VECTOR_OPERATION VAND(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    vector_and(vs, vt);
    *(v16 *)VACC_L = vs;
    return (vs);
#else
    vector_copy(VACC_L, vt);
    vector_and(VACC_L, vs);
    vector_copy(V_result, VACC_L);
    return;
#endif
}

VECTOR_OPERATION VNAND(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    vector_and(vt, vs);
    vector_fill(vs);
    vector_xor(vs, vt);
    *(v16 *)VACC_L = vs;
    return (vs);
#else
    vector_copy(VACC_L, vt);
    vector_and(VACC_L, vs);
    vector_fill(V_result);
    vector_xor(VACC_L, V_result);
    vector_copy(V_result, VACC_L);
    return;
#endif
}

VECTOR_OPERATION VOR(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    vector_or(vs, vt);
    *(v16 *)VACC_L = vs;
    return (vs);
#else
    vector_copy(VACC_L, vt);
    vector_or(VACC_L, vs);
    vector_copy(V_result, VACC_L);
    return;
#endif
}

VECTOR_OPERATION VNOR(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    vector_or(vt, vs);
    vector_fill(vs);
    vector_xor(vs, vt);
    *(v16 *)VACC_L = vs;
    return (vs);
#else
    vector_copy(VACC_L, vt);
    vector_or(VACC_L, vs);
    vector_fill(V_result);
    vector_xor(VACC_L, V_result);
    vector_copy(V_result, VACC_L);
    return;
#endif
}

VECTOR_OPERATION VXOR(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    vector_xor(vs, vt);
    *(v16 *)VACC_L = vs;
    return (vs);
#else
    vector_copy(VACC_L, vt);
    vector_xor(VACC_L, vs);
    vector_copy(V_result, VACC_L);
    return;
#endif
}

VECTOR_OPERATION VNXOR(v16 vs, v16 vt)
{
#ifdef ARCH_MIN_SSE2
    vector_xor(vt, vs);
    vector_fill(vs);
    vector_xor(vs, vt);
    *(v16 *)VACC_L = vs;
    return (vs);
#else
    vector_copy(VACC_L, vt);
    vector_xor(VACC_L, vs);
    vector_fill(V_result);
    vector_xor(VACC_L, V_result);
    vector_copy(V_result, VACC_L);
    return;
#endif
}
