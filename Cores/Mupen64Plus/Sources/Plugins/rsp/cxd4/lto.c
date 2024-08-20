/******************************************************************************\
* Project:  Primitive LTO Merger Substitute                                    *
* Authors:  Iconoclast                                                         *
* Release:  2018.03.17                                                         *
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

/*
 * A single compile-and-link command will be sufficient with this method.
 *
 * A command exemplifying this on UNIX with all optimizations in tact may be:
 *   $ cc --shared -o rsp.so lto.c -O3 -msse2 -DARCH_MIN_SSE2 -s
 *
 * To control the link-time stage during build with a separate command:
 *   $ gcc -c -o rsp.o lto.c -O3 -msse2 -DARCH_MIN_SSE2
 *   $ ld --shared -o rsp.so -lc rsp.o --strip-all
 */

#include "module.c"
#include "su.c"

#include "vu/vu.c"

#include "vu/multiply.c"
#include "vu/add.c"
#include "vu/select.c"
#include "vu/logical.c"
#include "vu/divide.c"
#if 0
#include "vu/pack.c"
#endif
