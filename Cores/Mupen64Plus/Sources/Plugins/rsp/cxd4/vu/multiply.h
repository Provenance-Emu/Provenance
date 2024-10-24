/******************************************************************************\
* Project:  Instruction Mnemonics for Vector Unit Computational Multiplies     *
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

#ifndef _MULTIPLY_H_
#define _MULTIPLY_H_

#include "vu.h"

/*
 * signed or unsigned muplication of fractions
 */
VECTOR_EXTERN
    VMULF  (v16 vs, v16 vt);
VECTOR_EXTERN
    VMULU  (v16 vs, v16 vt);
/*
 *  VRNDP  (v16 vs, v16 vt); # was on Ultra64 RCP but removed
 *  VMULQ  (v16 vs, v16 vt); # was on Ultra64 RCP but removed
 */

/*
 * double-precision multiplication of fractions
 */
VECTOR_EXTERN
    VMUDL  (v16 vs, v16 vt);
VECTOR_EXTERN
    VMUDM  (v16 vs, v16 vt);
VECTOR_EXTERN
    VMUDN  (v16 vs, v16 vt);
VECTOR_EXTERN
    VMUDH  (v16 vs, v16 vt);

/*
 * signed or unsigned accumulative multiplication and VMACQ
 */
VECTOR_EXTERN
    VMACF  (v16 vs, v16 vt);
VECTOR_EXTERN
    VMACU  (v16 vs, v16 vt);
/*
 *  VRNDN  (v16 vs, v16 vt); # was on Ultra64 RCP but removed
 *  VMACQ  (v16 vs, v16 vt); # mentioned probably by mistake in RSP manual
 */

/*
 * double-precision accumulative multiplication
 */
VECTOR_EXTERN
    VMADL  (v16 vs, v16 vt);
VECTOR_EXTERN
    VMADM  (v16 vs, v16 vt);
VECTOR_EXTERN
    VMADN  (v16 vs, v16 vt);
VECTOR_EXTERN
    VMADH  (v16 vs, v16 vt);

/*
 * an useful idea I thought of for the single-precision multiplies
 * VMULF and VMULU
 */
#ifndef SEMIFRAC
/*
 * acc = VS * VT;
 * acc = acc + 0x8000; # round value
 * acc = acc << 1; # partial value shift
 *
 * Wrong:  ACC(HI) = -((INT32)(acc) < 0)
 * Right:  ACC(HI) = -(SEMIFRAC < 0)
 */
#define SEMIFRAC    (VS[i]*VT[i]*2/2 + 0x8000/2)
#endif

#endif
