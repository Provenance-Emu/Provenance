/******************************************************************************\
* Project:  Instruction Mnemonics for Vector Unit Computational Test Selects   *
* Authors:  Iconoclast                                                         *
* Release:  2015.01.18                                                         *
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

#ifndef _SELECT_H_
#define _SELECT_H_

#include "vu.h"

VECTOR_EXTERN
    VLT    (v16 vs, v16 vt);
VECTOR_EXTERN
    VEQ    (v16 vs, v16 vt);
VECTOR_EXTERN
    VNE    (v16 vs, v16 vt);
VECTOR_EXTERN
    VGE    (v16 vs, v16 vt);
VECTOR_EXTERN
    VCL    (v16 vs, v16 vt);
VECTOR_EXTERN
    VCH    (v16 vs, v16 vt);
VECTOR_EXTERN
    VCR    (v16 vs, v16 vt);
VECTOR_EXTERN
    VMRG   (v16 vs, v16 vt);

#endif
