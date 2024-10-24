#ifndef __CORETYPES_H__
#define __CORETYPES_H__

#include <stdint.h>
#include <stdio.h>

#define ARRAY_LENGTH(x) (sizeof(x)/sizeof(x[0]))

typedef uint64_t UINT64;
#ifndef OSD_CPU_H
typedef uint32_t UINT32;
typedef uint16_t UINT16;
typedef uint8_t UINT8;
#endif

typedef int64_t INT64;
#ifndef OSD_CPU_H
typedef int32_t INT32;
typedef int16_t INT16;
typedef int8_t INT8;
#endif

#define core_file                 cdStream
#define core_fopen                cdStreamOpen
#define core_fseek                cdStreamSeek
#define core_fread(fc, buff, len) cdStreamRead(buff, 1, len, fc)
#define core_fclose               cdStreamClose
#define core_ftell                cdStreamTell

#endif
