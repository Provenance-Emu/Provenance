/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* jump.h:
**  Copyright (C) 2021 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#ifndef __MDFN_JUMP_H
#define __MDFN_JUMP_H

#include <setjmp.h>

//
// Be very careful with how MDFN_setjmp()/MDFN_longjmp() are used:
//
//  Don't change variables local to the function that called MDFN_setjmp() between
//  call MDFN_setjmp() and a potential call to MDFN_longjmp().
//
//  Don't call MDFN_longjmp() in the same function as the one that
//  called MDFN_setjmp(), nor in any function that may be inlined into the one
//  that called MDFN_setjmp().
//
//  The MDFN_jmp_buf object must be declared globally, and the call to
//  MDFN_setjmp()/MDFN_longjmp() must reference it directly.
//
//  https://man7.org/linux/man-pages/man3/longjmp.3.html
//
//  https://gcc.gnu.org/onlinedocs/gcc/Nonlocal-Gotos.html#Nonlocal-Gotos
//  https://gcc.gnu.org/bugzilla/show_bug.cgi?id=64242
//  https://gcc.gnu.org/bugzilla/show_bug.cgi?id=84521
//
namespace Mednafen
{

// Don't use __builtin_*jmp() if SJLJ exception handling is in use, as it's more likely
// to expose compiler bugs, and only use on x86_64 for now.
#if defined(__USING_SJLJ_EXCEPTIONS__) || (!defined(__clang__) && !defined(__GNUC__)) || !defined(__x86_64__)
 #if defined(HAVE_SIGLONGJMP)
  #define MDFN_setjmp(b) sigsetjmp(b, 0)
  #define MDFN_longjmp(b) siglongjmp(b, 1)

  typedef sigjmp_buf MDFN_jmp_buf;
 #elif defined(HAVE__LONGJMP)
  #define MDFN_setjmp(b) _setjmp(b)
  #define MDFN_longjmp(b) _longjmp(b, 1)

  typedef jmp_buf MDFN_jmp_buf;
 #else
  #define MDFN_setjmp(b) setjmp(b)
  #define MDFN_longjmp(b) longjmp(b, 1)

  typedef jmp_buf MDFN_jmp_buf;
 #endif
#else
 #define MDFN_setjmp(b) __builtin_setjmp(b)
 #define MDFN_longjmp(b) __builtin_longjmp(b, 1)

 #if defined(__clang__) 
  typedef void* MDFN_jmp_buf[5];
 #else
  typedef intptr_t MDFN_jmp_buf[5];
 #endif
#endif
}
#endif
