
#ifndef _SNSPCDEFS_H
#define _SNSPCDEFS_H

#define SNSPC_FLAG_N 0x80
#define SNSPC_FLAG_V 0x40
#define SNSPC_FLAG_P 0x20
#define SNSPC_FLAG_B 0x10
#define SNSPC_FLAG_H 0x08
#define SNSPC_FLAG_I 0x04
#define SNSPC_FLAG_Z 0x02
#define SNSPC_FLAG_C 0x01

#define SNSPC_MEM_SIZE		(0x10000)
#define SNSPC_RAM_SIZE		(0x10000)
#define SNSPC_ROM_ADDR		(0xFFC0)
#define SNSPC_ROM_SIZE		(0x0040)
#define SNSPC_VECTOR_BRK	(0xFFDE)
#define SNSPC_VECTOR_RESET	(0xFFFE)

// 1.027870mhz?
#define SNSPC_CYCLE (21)

#endif
