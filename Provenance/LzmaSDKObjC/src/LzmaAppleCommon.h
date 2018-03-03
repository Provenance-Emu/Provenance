/*
 *   Copyright (c) 2015 - 2017 Kulykov Oleh <info@resident.name>
 *
 *   Permission is hereby granted, free of charge, to any person obtaining a copy
 *   of this software and associated documentation files (the "Software"), to deal
 *   in the Software without restriction, including without limitation the rights
 *   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *   copies of the Software, and to permit persons to whom the Software is
 *   furnished to do so, subject to the following conditions:
 *
 *   The above copyright notice and this permission notice shall be included in
 *   all copies or substantial portions of the Software.
 *
 *   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *   THE SOFTWARE.
 */


#ifndef __LZMAAPPLECOMMON_H__
#define __LZMAAPPLECOMMON_H__ 1

#if defined(__APPLE__) || defined(TARGET_OS_MAC) || defined(TARGET_OS_IPHONE) || defined(TARGET_IPHONE_SIMULATOR) || defined(TARGET_OS_EMBEDDED)
#ifndef __APPLE__
#define __APPLE__ 1
#endif

#define LZMASDKOBJC_OMIT_UNUSED_CODE 1

#if defined(_UNICODE)
#undef _UNICODE
#endif

#ifndef ENV_HAVE_GCCVISIBILITYPATCH
#define ENV_HAVE_GCCVISIBILITYPATCH 1
#endif

#if ( defined(__amd64__) || defined(__amd64) || defined(__x86_64__) || defined(__x86_64) || defined(_M_X64) || defined(_AMD64_) || defined(_M_AMD64) )
#define __APPLE_64__ 1
#endif

#ifndef __APPLE_64__
#if ( defined(__LP64__) || defined(__ia64__) || defined(_IA64) || defined(__IA64__) || defined(__ia64) || defined(_M_IA64) )
#define __APPLE_64__ 1
#endif
#endif

#ifndef __APPLE_64__
#if ( defined(_WIN64) || defined(__X86_64__) || defined(WIN64) || defined(_LP64) || defined(ppc64) || defined(x86_64) )
#define __APPLE_64__ 1
#endif
#endif

#ifndef __APPLE_64__
#if ( defined(__x86_64__) || defined(__ppc64__) )
#define __APPLE_64__ 1
#endif
#endif


#ifndef __APPLE_64__
#define __APPLE_32__ 1
#endif

#endif

#if !defined(LZMASDKOBJC_EXTERN)
#if defined(__cplusplus) || defined(_cplusplus)
#define LZMASDKOBJC_EXTERN extern "C"
#else
#define LZMASDKOBJC_EXTERN extern
#endif
#endif

#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <pthread.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <string.h>
#include <wchar.h>
#include <assert.h>

typedef void *PVOID, *LPVOID;
typedef PVOID HANDLE;

#ifndef DWORD_SIZE
#define DWORD_SIZE 4
typedef uint32_t DWORD;
#endif


// MyWindows.h - removed prev. definition & MyWindows.cpp - implemented
LZMASDKOBJC_EXTERN DWORD GetLastError(void);

// unused
// void SetLastError(DWORD err) { errno = err; }

#if !defined(__OBJC__)
typedef signed char BOOL;
#endif

#if !defined(__cplusplus) && !defined(_cplusplus)
#define TRUE 1
#define FALSE 0
#endif


#ifndef USE_MIXER_ST
#define USE_MIXER_ST 1
#endif

#ifndef _7ZIP_ST
#define _7ZIP_ST 1
#endif

#endif

