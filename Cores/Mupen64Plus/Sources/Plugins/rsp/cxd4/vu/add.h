/******************************************************************************\
* Project:  Instruction Mnemonics for Vector Unit Computational Adds           *
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

#ifndef _ADD_H_
#define _ADD_H_

#include "vu.h"

VECTOR_EXTERN
    VADD   (v16 vs, v16 vt);
VECTOR_EXTERN
    VSUB   (v16 vs, v16 vt);
VECTOR_EXTERN
    VABS   (v16 vs, v16 vt);
VECTOR_EXTERN
    VADDC  (v16 vs, v16 vt);
VECTOR_EXTERN
    VSUBC  (v16 vs, v16 vt);
VECTOR_EXTERN
    VSAW   (v16 vs, v16 vt);

#endif
