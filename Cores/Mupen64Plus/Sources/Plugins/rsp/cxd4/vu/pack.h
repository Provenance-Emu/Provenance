/******************************************************************************\
* Project:  Instruction Mnemonics for Vector Unit Computational Packs          *
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

#ifndef _PACK_H_
#define _PACK_H_

#include "vu.h"

VECTOR_EXTERN
    VEXTT  (v16 vs, v16 vt);
VECTOR_EXTERN
    VEXTQ  (v16 vs, v16 vt);
VECTOR_EXTERN
    VEXTN  (v16 vs, v16 vt);
VECTOR_EXTERN
    VINST  (v16 vs, v16 vt);
VECTOR_EXTERN
    VINSQ  (v16 vs, v16 vt);
VECTOR_EXTERN
    VINSN  (v16 vs, v16 vt);

#endif
