/********************************************************************
 *                                                                  *
 * THIS FILE IS PART OF THE OggVorbis SOFTWARE CODEC SOURCE CODE.   *
 * USE, DISTRIBUTION AND REPRODUCTION OF THIS LIBRARY SOURCE IS     *
 * GOVERNED BY A BSD-STYLE SOURCE LICENSE INCLUDED WITH THIS SOURCE *
 * IN 'COPYING'. PLEASE READ THESE TERMS BEFORE DISTRIBUTING.       *
 *                                                                  *
 * THE OggVorbis SOURCE CODE IS (C) COPYRIGHT 1994-2002             *
 * by the Xiph.Org Foundation http://www.xiph.org/                  *
 *                                                                  *
 ********************************************************************

 function: #ifdef jail to whip a few platforms into the UNIX ideal.
 last mod: $Id: os_types.h 17712 2010-12-03 17:10:02Z xiphmont $

 ********************************************************************/

/*
 Modified for usage in Mednafen
*/

#ifndef _OS_TYPES_H
#define _OS_TYPES_H

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#define OGG_BIG_ENDIAN 	  4321
#define OGG_LITTLE_ENDIAN 1234

#ifdef MSB_FIRST
 #define OGG_BYTE_ORDER OGG_BIG_ENDIAN
#elif defined(LSB_FIRST)
 #define OGG_BYTE_ORDER OGG_LITTLE_ENDIAN
#else
 #error "ERROR"
#endif

/* make it easy on the folks that want to compile the libs with a
   different malloc than stdlib */
#define _ogg_malloc  malloc
#define _ogg_calloc  calloc
#define _ogg_realloc realloc
#define _ogg_free    free

#include <inttypes.h>

typedef int16_t ogg_int16_t;
typedef uint16_t ogg_uint16_t;
typedef int32_t ogg_int32_t;
typedef uint32_t ogg_uint32_t;
typedef int64_t ogg_int64_t;
typedef uint64_t ogg_uint64_t;

#endif  /* _OS_TYPES_H */
