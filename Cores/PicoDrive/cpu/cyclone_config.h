

/**
 * Cyclone 68000 configuration file
 *
 * Used for PicoDrive Cyclone build.
 * See config.h in Cyclone directory for option descriptions.
**/


#define USE_MS_SYNTAX               0
#define CYCLONE_FOR_GENESIS         2
#define COMPRESS_JUMPTABLE          0
#define MEMHANDLERS_ADDR_MASK       0

#define MEMHANDLERS_NEED_PC         0
#define MEMHANDLERS_NEED_PREV_PC    0
#define MEMHANDLERS_NEED_FLAGS      0
#define MEMHANDLERS_NEED_CYCLES     1
#define MEMHANDLERS_CHANGE_PC       0
#define MEMHANDLERS_CHANGE_FLAGS    0
#define MEMHANDLERS_CHANGE_CYCLES   1

#define MEMHANDLERS_DIRECT_PREFIX   "cyclone_"

#define USE_INT_ACK_CALLBACK        1

#define INT_ACK_NEEDS_STUFF         0
#define INT_ACK_CHANGES_CYCLES      0

#define USE_RESET_CALLBACK          1
#define USE_UNRECOGNIZED_CALLBACK   1
#define USE_AFLINE_CALLBACK         1

#define USE_CHECKPC_CALLBACK        1
#define USE_CHECKPC_OFFSETBITS_16   1
#define USE_CHECKPC_OFFSETBITS_8    0
#define USE_CHECKPC_DBRA            0

#define SPLIT_MOVEL_PD              1

#define EMULATE_TRACE               1
#define EMULATE_ADDRESS_ERRORS_JUMP 1
#define EMULATE_ADDRESS_ERRORS_IO   0
#define EMULATE_HALT                0

