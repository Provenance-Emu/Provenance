/******************************************************************************\
* Project:  Instruction Mnemonics for Vector Unit Computational Divides        *
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

#ifndef _DIVIDE_H_
#define _DIVIDE_H_

#include "vu.h"

VECTOR_EXTERN
    VRCP   (v16 vs, v16 vt);
VECTOR_EXTERN
    VRCPL  (v16 vs, v16 vt);
VECTOR_EXTERN
    VRCPH  (v16 vs, v16 vt);
VECTOR_EXTERN
    VMOV   (v16 vs, v16 vt);
VECTOR_EXTERN
    VRSQ   (v16 vs, v16 vt);
VECTOR_EXTERN
    VRSQL  (v16 vs, v16 vt);
VECTOR_EXTERN
    VRSQH  (v16 vs, v16 vt);
VECTOR_EXTERN
    VNOP   (v16 vs, v16 vt);

extern s32 DivIn;
extern s32 DivOut;

/*
 * Boolean flag:  Double-precision high was the last vector divide op?
 *
 * if (lastDivideOp == VRCP, VRCPL, VRSQ, VRSQL)
 *     DPH = false; // single-precision or double-precision low, not high
 * else if (lastDivideOp == VRCPH, VRSQH)
 *     DPH = true; // double-precision high
 * else if (lastDivideOp == VMOV, VNOP)
 *     DPH = DPH; // no change, divide-group ops but not real divides
 */
extern int DPH;

#endif
