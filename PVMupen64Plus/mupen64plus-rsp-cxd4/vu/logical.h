/******************************************************************************\
* Project:  Instruction Mnemonics for Vector Unit Computational Bit-Wise Logic *
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

#ifndef _LOGICAL_H_
#define _LOGICAL_H_

#include "vu.h"

VECTOR_EXTERN
    VAND   (v16 vs, v16 vt);
VECTOR_EXTERN
    VNAND  (v16 vs, v16 vt);
VECTOR_EXTERN
    VOR    (v16 vs, v16 vt);
VECTOR_EXTERN
    VNOR   (v16 vs, v16 vt);
VECTOR_EXTERN
    VXOR   (v16 vs, v16 vt);
VECTOR_EXTERN
    VNXOR  (v16 vs, v16 vt);

#endif
