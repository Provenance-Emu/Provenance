/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - macros.h                                                *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
 *   Copyright (C) 2002 Hacktarux                                          *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#ifndef M64P_R4300_MACROS_H
#define M64P_R4300_MACROS_H

#define SE8(a) ((int64_t) ((int8_t) (a)))
#define SE16(a) ((int64_t) ((int16_t) (a)))
#define SE32(a) ((int64_t) ((int32_t) (a)))

#define rrt *PC->f.r.rt
#define rrd *PC->f.r.rd
#define rfs PC->f.r.nrd
#define rrs *PC->f.r.rs
#define rsa PC->f.r.sa
#define irt *PC->f.i.rt
#define ioffset PC->f.i.immediate
#define iimmediate PC->f.i.immediate
#define irs *PC->f.i.rs
#define ibase *PC->f.i.rs
#define jinst_index PC->f.j.inst_index
#define lfbase PC->f.lf.base
#define lfft PC->f.lf.ft
#define lfoffset PC->f.lf.offset
#define cfft PC->f.cf.ft
#define cffs PC->f.cf.fs
#define cffd PC->f.cf.fd

// 32 bits macros
#ifndef M64P_BIG_ENDIAN
#define rrt32 *((int32_t*) PC->f.r.rt)
#define rrd32 *((int32_t*) PC->f.r.rd)
#define rrs32 *((int32_t*) PC->f.r.rs)
#define irs32 *((int32_t*) PC->f.i.rs)
#define irt32 *((int32_t*) PC->f.i.rt)
#else
#define rrt32 *((int32_t*) PC->f.r.rt + 1)
#define rrd32 *((int32_t*) PC->f.r.rd + 1)
#define rrs32 *((int32_t*) PC->f.r.rs + 1)
#define irs32 *((int32_t*) PC->f.i.rs + 1)
#define irt32 *((int32_t*) PC->f.i.rt + 1)
#endif

#endif /* M64P_R4300_MACROS_H */

