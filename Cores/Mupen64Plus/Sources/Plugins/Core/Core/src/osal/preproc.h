/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-core - osal/preproc.h                                     *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2009 Richard Goedeken                                   *
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

/* this header file is for system-dependent #defines, #includes, and typedefs */

#if !defined (OSAL_PREPROC_H)
#define OSAL_PREPROC_H

#if _MSC_VER

  /* macros */
  #define OSAL_BREAKPOINT_INTERRUPT __debugbreak();
  #define ALIGN(BYTES,DATA) __declspec(align(BYTES)) DATA
  #define osal_inline __inline

  /* string functions */
  #define osal_insensitive_strcmp(x, y) _stricmp(x, y)
  #define snprintf _snprintf
  #define strdup _strdup

  /* for isnan() */
  #include <float.h>

  #define isnan _isnan

#else  /* Not WIN32 */

  /* macros */
  #define OSAL_BREAKPOINT_INTERRUPT __asm__(" int $3; ");
  #define ALIGN(BYTES,DATA) DATA __attribute__((aligned(BYTES)))
  #define osal_inline inline

  /* string functions */
  #define osal_insensitive_strcmp(x, y) strcasecmp(x, y)

#endif

/* sign-extension macros */
#define SE8(a)  ((int64_t) ((int8_t) (a)))
#define SE16(a) ((int64_t) ((int16_t) (a)))
#define SE32(a) ((int64_t) ((int32_t) (a)))

#if !defined(M64P_BIG_ENDIAN)
  #if defined(__GNUC__) && (__GNUC__ > 4  || (__GNUC__ == 4 && __GNUC_MINOR__ >= 3))
    #define tohl(x) __builtin_bswap32((x))
  #else
    #define tohl(x) \
    ( \
    (((x) & 0x000000FF) << 24) | \
    (((x) & 0x0000FF00) <<  8) | \
    (((x) & 0x00FF0000) >>  8) | \
    (((x) & 0xFF000000) >> 24) \
    )
  #endif
  #define S8 3
  #define S16 2
  #define Sh16 1
#else
  #define tohl(x) (x)
  #define S8 0
  #define S16 0
  #define Sh16 0
#endif

#define fromhl(x) tohl((x))

#endif /* OSAL_PREPROC_H */

